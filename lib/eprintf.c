#include <emacs-module.h>
#include <locale.h>    // setlocale
#include <stdio.h>    // sprintf, fgets
#include <string.h>    // strlen
#include <stdlib.h>    // exit
#include <wchar.h>    // wprintf, fgetws

int plugin_is_GPL_compatible;

emacs_value eprintf(emacs_env*, ptrdiff_t, emacs_value*, void*);

int emacs_module_init(struct emacs_runtime *ert)
{
  if (ert->size < sizeof(*ert)) {
    return 1;
  }

  emacs_env *env = ert->get_environment(ert);

  if (env->size < sizeof(*env)) {
    return 2;
  }

  emacs_value func = env->make_function(env, 1, 1, eprintf, "My Emacs print function.", NULL);
  emacs_value func_symbol = env->intern(env, "eprintf");
  emacs_value defalias_args[] = {func_symbol, func};
  env->funcall(env, env->intern(env, "defalias"), 2, defalias_args);

  return 0;
}

/* eprintf の中身, 引数には一時ファイルの絶対パスを渡す */
emacs_value eprintf(emacs_env* env, ptrdiff_t nargs, emacs_value* args, void* data)
{
  /* ロケールの設定 */
  setlocale(LC_CTYPE, "ja_JP.UTF-8");

  /* 引数（一時ファイル名）の取得 */
  emacs_value str = args[0];
  ptrdiff_t size = 0;
  env->copy_string_contents(env, str, NULL, &size);
  char* tmp_filename;
  tmp_filename = (char*)malloc(size);
  env->copy_string_contents(env, str, tmp_filename, &size);

  /* 一時ファイルの読み取り及び出力 */
  FILE* tmp_file;
  wchar_t tmp_file_contents[256];
  tmp_file_contents[0] = '\0';
  tmp_file = fopen(tmp_filename, "r");
  if (tmp_file == NULL) {
    printf("ファイルが開けません。\n");
    exit(1);
  }
  fgetws(tmp_file_contents, 256, tmp_file);
  wchar_t* p;
  p = wcschr(tmp_file_contents, '\n');
  if (p) {
    *p = '\0';
  }
  wprintf(L"%ls", tmp_file_contents);
  fclose(tmp_file);

  free(tmp_filename);

  return env->intern(env, "t");
}
