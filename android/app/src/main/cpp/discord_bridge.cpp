#include <android/log.h>
#include <jni.h>

#include <cstdint>
#include <memory>
#include <sstream>
#include <string>

#define DISCORDPP_IMPLEMENTATION
#include "discordpp.h"

namespace {

JavaVM* g_vm = nullptr;
jobject g_bridge = nullptr;
jmethodID g_on_status = nullptr;
jmethodID g_on_connect_result = nullptr;
jmethodID g_on_replace_tokens = nullptr;
jmethodID g_on_clear_tokens = nullptr;
jmethodID g_on_presence_result = nullptr;

std::shared_ptr<discordpp::Client> g_client;
uint64_t g_application_id = 0;
std::string g_access;
std::string g_refresh;
bool g_connect_pending = false;
bool g_restoring = false;
bool g_refresh_tried = false;
bool g_authorize_after_disconnect = false;

JNIEnv* env_for_callback() {
  JNIEnv* env = nullptr;
  if (g_vm->GetEnv(reinterpret_cast<void**>(&env), JNI_VERSION_1_6) != JNI_OK) {
    if (g_vm->AttachCurrentThread(&env, nullptr) != JNI_OK) {
      return nullptr;
    }
  }
  return env;
}

void emit_status(const std::string& status) {
  JNIEnv* env = env_for_callback();
  if (env == nullptr || g_bridge == nullptr || g_on_status == nullptr) {
    return;
  }
  jstring value = env->NewStringUTF(status.c_str());
  env->CallVoidMethod(g_bridge, g_on_status, value);
  env->DeleteLocalRef(value);
}

void emit_connect_result(const std::string& access, const std::string& refresh, const std::string& error) {
  JNIEnv* env = env_for_callback();
  if (env == nullptr || g_bridge == nullptr || g_on_connect_result == nullptr) {
    return;
  }
  jstring access_value = access.empty() ? nullptr : env->NewStringUTF(access.c_str());
  jstring refresh_value = refresh.empty() ? nullptr : env->NewStringUTF(refresh.c_str());
  jstring error_value = error.empty() ? nullptr : env->NewStringUTF(error.c_str());
  env->CallVoidMethod(g_bridge, g_on_connect_result, access_value, refresh_value, error_value);
  if (access_value != nullptr) {
    env->DeleteLocalRef(access_value);
  }
  if (refresh_value != nullptr) {
    env->DeleteLocalRef(refresh_value);
  }
  if (error_value != nullptr) {
    env->DeleteLocalRef(error_value);
  }
}

void emit_replace_tokens(const std::string& access, const std::string& refresh) {
  JNIEnv* env = env_for_callback();
  if (env == nullptr || g_bridge == nullptr || g_on_replace_tokens == nullptr) {
    return;
  }
  jstring access_value = env->NewStringUTF(access.c_str());
  jstring refresh_value = env->NewStringUTF(refresh.c_str());
  env->CallVoidMethod(g_bridge, g_on_replace_tokens, access_value, refresh_value);
  env->DeleteLocalRef(access_value);
  env->DeleteLocalRef(refresh_value);
}

void emit_presence_result(const std::string& error) {
  JNIEnv* env = env_for_callback();
  if (env == nullptr || g_bridge == nullptr || g_on_presence_result == nullptr) {
    return;
  }
  jstring value = error.empty() ? nullptr : env->NewStringUTF(error.c_str());
  env->CallVoidMethod(g_bridge, g_on_presence_result, value);
  if (value != nullptr) {
    env->DeleteLocalRef(value);
  }
}

void emit_clear_tokens() {
  JNIEnv* env = env_for_callback();
  if (env == nullptr || g_bridge == nullptr || g_on_clear_tokens == nullptr) {
    return;
  }
  env->CallVoidMethod(g_bridge, g_on_clear_tokens);
}

std::string status_name(discordpp::Client::Status status, discordpp::Client::Error error) {
  if (error != discordpp::Client::Error::None && status != discordpp::Client::Status::Ready) {
    return "error";
  }
  switch (status) {
    case discordpp::Client::Status::Ready:
      return "ready";
    case discordpp::Client::Status::Connecting:
    case discordpp::Client::Status::Connected:
    case discordpp::Client::Status::Reconnecting:
    case discordpp::Client::Status::Disconnecting:
    case discordpp::Client::Status::HttpWait:
      return "connecting";
    default:
      return "disconnected";
  }
}

void finish_connect_error(const std::string& error) {
  if (!g_connect_pending) {
    return;
  }
  g_connect_pending = false;
  emit_connect_result("", "", error);
}

void connect_with_token(const std::string& access);

void clear_session() {
  g_access.clear();
  g_refresh.clear();
  g_restoring = false;
  emit_clear_tokens();
  emit_status("disconnected");
}

void refresh_or_clear() {
  if (g_refresh_tried || g_refresh.empty() || g_client == nullptr || g_application_id == 0) {
    clear_session();
    finish_connect_error("token refresh failed");
    return;
  }
  g_refresh_tried = true;
  auto refresh = g_refresh;
  g_client->RefreshToken(
    g_application_id,
    refresh,
    [](discordpp::ClientResult result,
       std::string access_token,
       std::string refresh_token,
       discordpp::AuthorizationTokenType,
       int32_t,
       std::string) {
      if (!result.Successful()) {
        clear_session();
        finish_connect_error("token refresh failed");
        return;
      }
      g_access = access_token;
      g_refresh = refresh_token;
      emit_replace_tokens(access_token, refresh_token);
      connect_with_token(access_token);
    });
}

void connect_with_token(const std::string& access) {
  if (g_client == nullptr) {
    return;
  }
  g_access = access;
  g_client->UpdateToken(
    discordpp::AuthorizationTokenType::Bearer,
    access,
    [](discordpp::ClientResult result) {
      if (!result.Successful()) {
        refresh_or_clear();
        return;
      }
      g_client->Connect();
    });
}

void begin_authorize();

void ensure_client() {
  if (g_client != nullptr) {
    return;
  }
  g_client = std::make_shared<discordpp::Client>();
  g_client->AddLogCallback(
    [](auto message, auto severity) {
      __android_log_print(
        ANDROID_LOG_INFO,
        "DiscordSdk",
        "[%s] %s",
        discordpp::EnumToString(severity),
        std::string(message).c_str());
    },
    discordpp::LoggingSeverity::Info);
  g_client->SetStatusChangedCallback(
    [](discordpp::Client::Status status, discordpp::Client::Error error, int32_t error_detail) {
      const auto status_text = discordpp::Client::StatusToString(status);
      const auto error_text = discordpp::Client::ErrorToString(error);
      __android_log_print(
        ANDROID_LOG_INFO,
        "DiscordSdk",
        "status %s error %s detail %d",
        status_text.c_str(),
        error_text.c_str(),
        error_detail);
      if (status == discordpp::Client::Status::Ready) {
        g_restoring = false;
        emit_status("ready");
        if (g_connect_pending) {
          g_connect_pending = false;
          emit_connect_result(g_access, g_refresh, "");
        }
        return;
      }
      if (g_restoring && error == discordpp::Client::Error::UnexpectedClose) {
        refresh_or_clear();
        return;
      }
      if (g_authorize_after_disconnect && status == discordpp::Client::Status::Disconnected) {
        g_authorize_after_disconnect = false;
        begin_authorize();
        return;
      }
      emit_status(status_name(status, error));
    });
}

void prepare_authorize() {
  if (g_client == nullptr) {
    return;
  }
  const auto status = g_client->GetStatus();
  if (status == discordpp::Client::Status::Disconnected) {
    g_authorize_after_disconnect = false;
    begin_authorize();
    return;
  }
  g_authorize_after_disconnect = true;
  if (status != discordpp::Client::Status::Disconnecting) {
    g_client->Disconnect();
  }
}

void begin_authorize() {
  auto code_verifier = g_client->CreateAuthorizationCodeVerifier();
  discordpp::AuthorizationArgs args{};
  args.SetClientId(g_application_id);
  args.SetScopes(discordpp::Client::GetDefaultPresenceScopes());
  args.SetCodeChallenge(code_verifier.Challenge());
  g_client->IsDiscordAppInstalled([](bool) {});
  g_client->Authorize(
    args,
    [code_verifier](auto result, auto code, auto redirect_uri) {
      if (!result.Successful()) {
        std::ostringstream error;
        error << result.Error();
        finish_connect_error(error.str());
        return;
      }
      g_client->GetToken(
        g_application_id,
        code,
        code_verifier.Verifier(),
        redirect_uri,
        [](discordpp::ClientResult token_result,
           std::string access_token,
           std::string refresh_token,
           discordpp::AuthorizationTokenType,
           int32_t,
           std::string) {
          if (!token_result.Successful()) {
            finish_connect_error("token exchange failed");
            return;
          }
          g_access = access_token;
          g_refresh = refresh_token;
          g_refresh_tried = false;
          g_restoring = false;
          connect_with_token(access_token);
        });
    });
}

}  // namespace

extern "C" JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM* vm, void*) {
  g_vm = vm;
  return JNI_VERSION_1_6;
}

extern "C" JNIEXPORT void JNICALL
Java_com_byjofrey_car_1presence_DiscordSdkBridge_nativeInit(JNIEnv* env, jobject thiz) {
  if (g_bridge != nullptr) {
    env->DeleteGlobalRef(g_bridge);
  }
  g_bridge = env->NewGlobalRef(thiz);
  jclass cls = env->GetObjectClass(thiz);
  g_on_status = env->GetMethodID(cls, "onStatus", "(Ljava/lang/String;)V");
  g_on_connect_result = env->GetMethodID(
    cls,
    "onConnectResult",
    "(Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;)V");
  g_on_replace_tokens = env->GetMethodID(
    cls,
    "onReplaceTokens",
    "(Ljava/lang/String;Ljava/lang/String;)V");
  g_on_clear_tokens = env->GetMethodID(cls, "onClearTokens", "()V");
  g_on_presence_result = env->GetMethodID(cls, "onPresenceResult", "(Ljava/lang/String;)V");
}

extern "C" JNIEXPORT void JNICALL
Java_com_byjofrey_car_1presence_DiscordSdkBridge_nativeRunCallbacks(JNIEnv*, jobject) {
  if (g_client != nullptr) {
    discordpp::RunCallbacks();
  }
}

extern "C" JNIEXPORT void JNICALL
Java_com_byjofrey_car_1presence_DiscordSdkBridge_nativeStart(
  JNIEnv* env,
  jobject,
  jstring application_id) {
  const char* raw = env->GetStringUTFChars(application_id, nullptr);
  std::string text = raw == nullptr ? "" : raw;
  if (raw != nullptr) {
    env->ReleaseStringUTFChars(application_id, raw);
  }
  g_application_id = text.empty() ? 0 : std::stoull(text);
  ensure_client();
}

extern "C" JNIEXPORT void JNICALL
Java_com_byjofrey_car_1presence_DiscordSdkBridge_nativeRestore(
  JNIEnv* env,
  jobject,
  jstring access_token,
  jstring refresh_token) {
  ensure_client();
  const char* access_raw = access_token == nullptr ? nullptr : env->GetStringUTFChars(access_token, nullptr);
  const char* refresh_raw = refresh_token == nullptr ? nullptr : env->GetStringUTFChars(refresh_token, nullptr);
  std::string access = access_raw == nullptr ? "" : access_raw;
  std::string refresh = refresh_raw == nullptr ? "" : refresh_raw;
  if (access_raw != nullptr) {
    env->ReleaseStringUTFChars(access_token, access_raw);
  }
  if (refresh_raw != nullptr) {
    env->ReleaseStringUTFChars(refresh_token, refresh_raw);
  }
  if (access.empty()) {
    emit_status("disconnected");
    return;
  }
  g_refresh = refresh;
  g_refresh_tried = false;
  g_restoring = true;
  connect_with_token(access);
}

extern "C" JNIEXPORT void JNICALL
Java_com_byjofrey_car_1presence_DiscordSdkBridge_nativeConnect(JNIEnv* env, jobject, jstring application_id) {
  const char* raw = env->GetStringUTFChars(application_id, nullptr);
  std::string text = raw == nullptr ? "" : raw;
  if (raw != nullptr) {
    env->ReleaseStringUTFChars(application_id, raw);
  }
  if (!text.empty()) {
    g_application_id = std::stoull(text);
  }
  ensure_client();
  if (g_application_id == 0) {
    g_connect_pending = true;
    finish_connect_error("missing application id");
    return;
  }
  g_connect_pending = true;
  g_refresh_tried = false;
  prepare_authorize();
}

extern "C" JNIEXPORT void JNICALL
Java_com_byjofrey_car_1presence_DiscordSdkBridge_nativeDisconnect(JNIEnv*, jobject) {
  auto token = g_access;
  auto application_id = g_application_id;
  g_access.clear();
  g_refresh.clear();
  g_connect_pending = false;
  g_restoring = false;
  g_authorize_after_disconnect = false;
  if (g_client != nullptr) {
    if (!token.empty() && application_id != 0) {
      g_client->RevokeToken(application_id, token, [](discordpp::ClientResult) {});
    }
    const auto status = g_client->GetStatus();
    if (status != discordpp::Client::Status::Disconnected &&
        status != discordpp::Client::Status::Disconnecting) {
      g_client->Disconnect();
    }
  }
  emit_status("disconnected");
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_byjofrey_car_1presence_DiscordSdkBridge_nativeStatus(JNIEnv* env, jobject) {
  if (g_client == nullptr) {
    return env->NewStringUTF("disconnected");
  }
  auto status = status_name(g_client->GetStatus(), discordpp::Client::Error::None);
  return env->NewStringUTF(status.c_str());
}

extern "C" JNIEXPORT jobject JNICALL
Java_com_byjofrey_car_1presence_DiscordSdkBridge_nativeCurrentUser(JNIEnv* env, jobject) {
  if (g_client == nullptr) {
    return nullptr;
  }
  auto user = g_client->GetCurrentUserV2();
  if (!user) {
    return nullptr;
  }
  jclass map_class = env->FindClass("java/util/HashMap");
  jmethodID init = env->GetMethodID(map_class, "<init>", "()V");
  jmethodID put = env->GetMethodID(
    map_class,
    "put",
    "(Ljava/lang/Object;Ljava/lang/Object;)Ljava/lang/Object;");
  jobject map = env->NewObject(map_class, init);
  auto put_string = [&](const char* key, const std::string& value) {
    jstring key_value = env->NewStringUTF(key);
    jstring string_value = env->NewStringUTF(value.c_str());
    env->CallObjectMethod(map, put, key_value, string_value);
    env->DeleteLocalRef(key_value);
    env->DeleteLocalRef(string_value);
  };
  put_string("userId", std::to_string(user->Id()));
  put_string("username", user->Username());
  put_string("displayName", user->DisplayName());
  return map;
}

std::string jstring_to_std(JNIEnv* env, jstring value) {
  if (value == nullptr) {
    return "";
  }
  const char* raw = env->GetStringUTFChars(value, nullptr);
  std::string text = raw == nullptr ? "" : raw;
  if (raw != nullptr) {
    env->ReleaseStringUTFChars(value, raw);
  }
  return text;
}

extern "C" JNIEXPORT void JNICALL
Java_com_byjofrey_car_1presence_DiscordSdkBridge_nativeUpdatePresence(
  JNIEnv* env,
  jobject,
  jstring details,
  jstring state) {
  if (g_client == nullptr || g_client->GetStatus() != discordpp::Client::Status::Ready) {
    emit_presence_result("not ready");
    return;
  }
  discordpp::Activity activity{};
  activity.SetType(discordpp::ActivityTypes::Playing);
  activity.SetDetails(jstring_to_std(env, details));
  activity.SetState(jstring_to_std(env, state));
  g_client->UpdateRichPresence(activity, [](discordpp::ClientResult result) {
    emit_presence_result(result.Successful() ? "" : "update presence failed");
  });
}

extern "C" JNIEXPORT void JNICALL
Java_com_byjofrey_car_1presence_DiscordSdkBridge_nativeClearPresence(JNIEnv*, jobject) {
  if (g_client != nullptr && g_client->GetStatus() == discordpp::Client::Status::Ready) {
    g_client->ClearRichPresence();
  }
}
