/*
 * choir_ios.m — the `choir_ios` NIF (ChoirCoach.Ios): Choir Coach's iOS-only
 * native bits that neither Mob nor mob_audio_io does yet. The audio engine
 * itself is mob_audio_io's streams and the app's c_src/choir_audio.c.
 *
 *   screen_size/0   the main screen in points: Mob's :mob_nif.screen_info/0
 *                   is test-harness-only on iOS and compiled out of release
 *                   builds. Remove once Mob ships it in release.
 *   set_speaker/1   route the output to the speaker even with headphones
 *                   connected (overrideOutputAudioPort), or back to iOS's
 *                   choice. mob_audio_io lets iOS route the output.
 *   watch_route/1   tell a process when the route loses its device
 *                   (headphones unplugged, Bluetooth gone), and whether a
 *                   microphone went with it: mob_audio_io reports route
 *                   changes without that reason, and the engine pauses
 *                   then rather than go on out loud.
 *
 * Built by the in-repo plugin plugins/choir_ios (lang: :objc, platform:
 * :ios).
 */

#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>
#include <erl_nif.h>
#include <os/log.h>
#include <pthread.h>
#include <stdbool.h>

static pthread_mutex_t watcher_lock = PTHREAD_MUTEX_INITIALIZER;
static ErlNifPid watcher;
static bool has_watcher;

static ERL_NIF_TERM atom(ErlNifEnv *env, const char *name) { return enif_make_atom(env, name); }

/* screen_size() -> {Width, Height}: the main screen in points, read on the
 * main thread as Mob does (hence dirty IO). */
static ERL_NIF_TERM nif_screen_size(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
    (void)argc;
    (void)argv;
    __block CGRect bounds = CGRectZero;
    if ([NSThread isMainThread]) {
        bounds = [UIScreen mainScreen].bounds;
    } else {
        dispatch_sync(dispatch_get_main_queue(), ^{
          bounds = [UIScreen mainScreen].bounds;
        });
    }
    return enif_make_tuple2(env, enif_make_double(env, bounds.size.width), enif_make_double(env, bounds.size.height));
}

/* set_speaker(On) -> ok | {error, Detail}: the speaker override on or off. */
static ERL_NIF_TERM nif_set_speaker(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
    (void)argc;
    bool on = enif_is_identical(argv[0], atom(env, "true"));
    if (!on && !enif_is_identical(argv[0], atom(env, "false"))) return enif_make_badarg(env);
    @autoreleasepool {
        NSError *err = nil;
        AVAudioSessionPortOverride o = on ? AVAudioSessionPortOverrideSpeaker : AVAudioSessionPortOverrideNone;
        if ([[AVAudioSession sharedInstance] overrideOutputAudioPort:o error:&err]) return atom(env, "ok");
        const char *detail = err ? err.localizedDescription.UTF8String : "failed";
        size_t n = strlen(detail);
        ERL_NIF_TERM bin;
        memcpy(enif_make_new_binary(env, n, &bin), detail, n);
        return enif_make_tuple2(env, atom(env, "error"), bin);
    }
}

/* A route change: when the old route's device is gone, whether one of its
 * microphones went too, to the watcher. */
static void on_route_change(NSNotification *note) {
    NSUInteger reason = [note.userInfo[AVAudioSessionRouteChangeReasonKey] unsignedIntegerValue];
    if (reason != AVAudioSessionRouteChangeReasonOldDeviceUnavailable) return;
    AVAudioSessionRouteDescription *old = note.userInfo[AVAudioSessionRouteChangePreviousRouteKey];
    NSArray<AVAudioSessionPortDescription *> *available = [AVAudioSession sharedInstance].availableInputs;
    bool input_gone = false;
    for (AVAudioSessionPortDescription *p in old.inputs) {
        bool still = false;
        for (AVAudioSessionPortDescription *a in available)
            if ([a.UID isEqualToString:p.UID]) still = true;
        if (!still) input_gone = true;
    }
    os_log(OS_LOG_DEFAULT, "choir_ios: route lost its device%{public}s", input_gone ? " (and its microphone)" : "");
    pthread_mutex_lock(&watcher_lock);
    if (has_watcher) {
        ErlNifEnv *env = enif_alloc_env();
        ERL_NIF_TERM msg = enif_make_tuple3(env, atom(env, "choir_ios"), atom(env, "route_lost"),
                                            atom(env, input_gone ? "true" : "false"));
        enif_send(NULL, &watcher, env, msg);
        enif_free_env(env);
    }
    pthread_mutex_unlock(&watcher_lock);
}

static void observe_routes(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
      NSOperationQueue *queue = [NSOperationQueue new];
      queue.maxConcurrentOperationCount = 1;
      [[NSNotificationCenter defaultCenter] addObserverForName:AVAudioSessionRouteChangeNotification
                                                        object:[AVAudioSession sharedInstance]
                                                         queue:queue
                                                    usingBlock:^(NSNotification *n) {
                                                      on_route_change(n);
                                                    }];
    });
}

/* watch_route(Pid) -> ok: Pid gets {choir_ios, route_lost, InputGone}. */
static ERL_NIF_TERM nif_watch_route(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
    (void)argc;
    ErlNifPid pid;
    if (!enif_get_local_pid(env, argv[0], &pid)) return enif_make_badarg(env);
    pthread_mutex_lock(&watcher_lock);
    watcher = pid;
    has_watcher = true;
    pthread_mutex_unlock(&watcher_lock);
    @autoreleasepool {
        observe_routes();
    }
    return atom(env, "ok");
}

static ErlNifFunc nif_funcs[] = {
    {"screen_size", 0, nif_screen_size, ERL_NIF_DIRTY_JOB_IO_BOUND},
    {"set_speaker", 1, nif_set_speaker, ERL_NIF_DIRTY_JOB_IO_BOUND},
    {"watch_route", 1, nif_watch_route, ERL_NIF_DIRTY_JOB_IO_BOUND},
};

ERL_NIF_INIT(Elixir.ChoirCoach.Ios, nif_funcs, NULL, NULL, NULL, NULL)
