// macOS のメディアキー (音量/輝度/再生制御) をブロックするネイティブアドオン。
// CGEventTap を HID レベルに張って NX_SYSDEFINED イベントを横取りし、
// 該当キーのイベントを破棄する。アクセシビリティ権限が必要。
#include <napi.h>
#import <Cocoa/Cocoa.h>
#import <ApplicationServices/ApplicationServices.h>
#import <IOKit/hidsystem/ev_keymap.h>

static CFMachPortRef gEventTap = NULL;
static CFRunLoopSourceRef gRunLoopSource = NULL;

// イベントタップのコールバック。NX_SYSDEFINED の AUX_CONTROL_BUTTONS
// を判定し、対象キーなら NULL を返してイベントを握りつぶす。
static CGEventRef EventTapCallback(CGEventTapProxy proxy, CGEventType type,
                                    CGEventRef event, void *refcon) {
  // タップが無効化された場合は再有効化して素通り
  if (type == kCGEventTapDisabledByTimeout || type == kCGEventTapDisabledByUserInput) {
    if (gEventTap) CGEventTapEnable(gEventTap, true);
    return event;
  }

  // NX_SYSDEFINED == 14 のみ処理対象
  if ((int)type != NX_SYSDEFINED) {
    return event;
  }

  @autoreleasepool {
    NSEvent *nsEvent = [NSEvent eventWithCGEvent:event];
    if (!nsEvent) return event;
    if (nsEvent.subtype != NX_SUBTYPE_AUX_CONTROL_BUTTONS) return event;

    NSInteger data1 = nsEvent.data1;
    int keyCode = (int)((data1 & 0xFFFF0000) >> 16);

    switch (keyCode) {
      case NX_KEYTYPE_SOUND_UP:
      case NX_KEYTYPE_SOUND_DOWN:
      case NX_KEYTYPE_MUTE:
      case NX_KEYTYPE_BRIGHTNESS_UP:
      case NX_KEYTYPE_BRIGHTNESS_DOWN:
      case NX_KEYTYPE_PLAY:
      case NX_KEYTYPE_FAST:
      case NX_KEYTYPE_REWIND:
      case NX_KEYTYPE_NEXT:
      case NX_KEYTYPE_PREVIOUS:
      case NX_KEYTYPE_EJECT:
      case NX_KEYTYPE_ILLUMINATION_UP:
      case NX_KEYTYPE_ILLUMINATION_DOWN:
      case NX_KEYTYPE_ILLUMINATION_TOGGLE:
        // イベント破棄
        return NULL;
      default:
        return event;
    }
  }
}

static bool startTap() {
  if (gEventTap) return true;

  CGEventMask mask = CGEventMaskBit(NX_SYSDEFINED);
  gEventTap = CGEventTapCreate(kCGHIDEventTap,
                                kCGHeadInsertEventTap,
                                kCGEventTapOptionDefault,
                                mask,
                                EventTapCallback,
                                NULL);
  if (!gEventTap) return false;

  gRunLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, gEventTap, 0);
  CFRunLoopAddSource(CFRunLoopGetMain(), gRunLoopSource, kCFRunLoopCommonModes);
  CGEventTapEnable(gEventTap, true);
  return true;
}

static void stopTap() {
  if (gEventTap) {
    CGEventTapEnable(gEventTap, false);
  }
  if (gRunLoopSource) {
    CFRunLoopRemoveSource(CFRunLoopGetMain(), gRunLoopSource, kCFRunLoopCommonModes);
    CFRelease(gRunLoopSource);
    gRunLoopSource = NULL;
  }
  if (gEventTap) {
    CFRelease(gEventTap);
    gEventTap = NULL;
  }
}

static Napi::Value Start(const Napi::CallbackInfo& info) {
  return Napi::Boolean::New(info.Env(), startTap());
}

static Napi::Value Stop(const Napi::CallbackInfo& info) {
  stopTap();
  return info.Env().Undefined();
}

// アクセシビリティ権限が付与されているかを確認する（プロンプトなし）
static Napi::Value IsTrusted(const Napi::CallbackInfo& info) {
  NSDictionary *options = @{(__bridge id)kAXTrustedCheckOptionPrompt: @NO};
  bool trusted = AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)options);
  return Napi::Boolean::New(info.Env(), trusted);
}

// アクセシビリティ権限のプロンプトを表示する
static Napi::Value RequestTrust(const Napi::CallbackInfo& info) {
  NSDictionary *options = @{(__bridge id)kAXTrustedCheckOptionPrompt: @YES};
  bool trusted = AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)options);
  return Napi::Boolean::New(info.Env(), trusted);
}

static Napi::Object Init(Napi::Env env, Napi::Object exports) {
  exports.Set("start", Napi::Function::New(env, Start));
  exports.Set("stop", Napi::Function::New(env, Stop));
  exports.Set("isTrusted", Napi::Function::New(env, IsTrusted));
  exports.Set("requestTrust", Napi::Function::New(env, RequestTrust));
  return exports;
}

NODE_API_MODULE(media_key_blocker, Init)
