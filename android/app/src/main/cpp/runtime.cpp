#include <jni.h>
#include <cstdlib>
#include <cstring>
#include <vector>
#include <string>
#include <unistd.h>
#include <fcntl.h>
namespace node { int Start(int argc, char** argv); }
extern "C" JNIEXPORT jint JNICALL
Java_app_vocashelf_vocashelf_GatewayService_startRuntime(JNIEnv* env, jobject, jstring directory) {
  const char* raw = env->GetStringUTFChars(directory, nullptr);
  std::string root(raw);
  env->ReleaseStringUTFChars(directory, raw);
  chdir(root.c_str());
  setenv("TMPDIR", (root + "/tmp").c_str(), 1);
  setenv("VOCASHELF_SESSION_DIR", (root + "/accounts").c_str(), 1);
  setenv("VOCASHELF_HOST", "127.0.0.1", 1);
  setenv("VOCASHELF_PORT", "5418", 1);
  setenv("VOCALO1NG_ANDROID", "1", 1);
  const int log = open((root + "/runtime.log").c_str(), O_WRONLY | O_CREAT | O_TRUNC, 0600);
  if (log >= 0) { dup2(log, STDOUT_FILENO); dup2(log, STDERR_FILENO); close(log); }
  // libuv requires all argument strings in contiguous writable storage.
  const char args[] = "node\0server/android_bootstrap.cjs\0";
  char* storage = static_cast<char*>(malloc(sizeof(args)));
  memcpy(storage, args, sizeof(args));
  char* argv[] = {storage, storage + 5, nullptr};
  const int result = node::Start(2, argv);
  free(storage);
  return result;
}
