;;; Video Converter for Walkman written by suyeden -*- Emacs-Lisp -*-

;; Copyright (C) 2021 suyeden

;; Author: suyeden
;; Version: 1.0.0
;; Keywords: tools
;; Package-Requires: ((emacs "27.1") (master-lib "1.0.0") (eprintf.dll) (ffmpeg "4.2.1"))

;; This file is NOT part of GNU Emacs.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; Walkman向け動画変換スクリプト
;; '--script' オプションで使われることを想定しています

;;; Code:

(defvar vcw-video-ext-list
  '("mp4" "flv" "webm" "mkv" "wmv" "mpeg" "mpg" "m4a" "m4v" "avi" "mov" "m2ts" "ts" "qt" "asf" "ogm")
  "動画ファイルの拡張子一覧リスト")
(defvar vcw-audio-ext-list
  '("wav" "wave" "aif" "mp3" "mid" "aac" "flac" "wma" "asf" "3gp" "3g2" "ogg" "oga" "mov" "m4a" "alac" "ape" "mac" "tta" "mka" "mkv" "aiff" "aifc" "ac3" "oma" "aa3" "opus" "omg" "tak")
  "音声ファイルの拡張子一覧リスト")
(defvar vcw-stop-flag nil
  "動画変換の中断を検知")
(defvar vcw-dst-dir-original "vcw_original"
  "変換元ファイルの移動先ディレクトリ名")
(defvar vcw-dst-dir-error "vcw_error"
  "変換エラーを起こした変換元ファイルの移動先ディレクトリ名")
(defvar vcw-log-file "vcw-log.txt"
  "ログファイル名")
(defvar vcw-error-log-file "vcw-error.txt"
  "エラーログファイル名")
(defvar vcw-mode-list '("MP4" "低画質MP4" "MP3" "縦動画回転変換" "入力やり直し")
  "モードリスト")
(defvar vcw-tateyoko-mode-list '("MP4" "低画質MP4")
  "縦動画横向き変換のモード内モード")
(defvar vcw-bitrate-normal "384"
  "通常動画のビットレート")
(defvar vcw-bitrate-lq "256"
  "低画質動画のビットレート")
(defvar vcw-config-list nil
  "設定リスト")
(defvar vcw-lib-path (expand-file-name (format "%s/../lib" load-file-name))
  "ライブラリは lib ディレクトリに置く")

;; library loading
(load (expand-file-name "master-lib.el" vcw-lib-path) nil t)

(defun main ()
  "動画ファイルをウォークマン向けの形式に変換するスクリプト"
  (let ((target-dir nil)
        (input-mode nil)
        (input-mode-in-mode nil)
        (output-dir nil)
        (conv-all-files-or-not nil)
        (current-dir-path nil)
        (start-time 0)
        (error-file nil)
        (converted-files-count 0)
        (error-files-count 0))
    ;; 初期化
    (my-init)
    ;; カレントディレクトリの記録
    (setq current-dir-path default-directory)
    (catch 'vcw-quit
      ;; 各種設定取得
      ;; 設定リストのフォーマットは
      ;; (対象ディレクトリ  モード  モード内モード  出力先ディレクトリ  全ファイル変換フラグ)
      (catch 'dir-ask-end
        (while t
          ;; 変換対象ディレクトリの指定
          (setq target-dir (my-read-str (format "\n 操作対象フォルダーのパスを入力 （現在地 \"%s\" の利用時は . を入力）\n そのままリターンすると入力を終了、 vcw-stop と入力すると変換を行わずに強制終了します\n : " default-directory)))
          (princ "\n")
          ;; vcw-stop が入力された場合は中断する
          (when (string= "vcw-stop" (file-name-nondirectory target-dir))
            (princ "\n Quit!\n\n")
            (throw 'vcw-quit t))
          ;; 入力値なしの場合は設定読み取りの終了
          (if (string= "" (format "%s" target-dir))
              (progn
                (princ "\n ----------\n\n")
                (throw 'dir-ask-end t))
            (setq target-dir (expand-file-name target-dir)))
          (catch 'vcw-ask-retry
            ;; モードの指定
            (setq input-mode (read-mode (format " \"%s\"\n に対して適用するモードを数字で入力してください" target-dir) vcw-mode-list nil))
            (princ "\n")
            ;; 縦動画変換の時はモード内モードの指定
            (when (string= "4" (format "%s" input-mode))
              (setq input-mode-in-mode (read-mode nil vcw-tateyoko-mode-list nil))
              (princ "\n"))
            ;; 入力をやり直す場合
            (when (string= "5" (format "%s" input-mode))
              (my-princ (format "\n \"%s\" に対する操作を中断しました\n\n" target-dir))
              (princ " \n ----------\n\n")
              ;; 各種変数初期化
              (setq target-dir nil)       ; 対象ディレクトリ
              (setq input-mode nil)           ; モード
              (setq input-mode-in-mode nil)   ; モード内モード
              (setq output-dir nil)       ; 出力先ディレクトリ
              (setq conv-all-files-or-not nil) ; 全ファイル変換フラグ
              (throw 'vcw-ask-retry t))
            ;; 出力先ディレクトリの指定
            (unless (file-exists-p target-dir) ; 操作対象ディレクトリが存在しない場合は、作ってからそこに移動する
              (make-directory target-dir t))
            (cd target-dir)
            (if (string= "3" (format "%s" input-mode))
                (setq output-dir (my-read-str (format " 出力先フォルダーのパスを入力 （デフォルトは \"%s\" ）\n 相対パスは \"%s\" を基準に入力してください\n vcw-stop と入力すると現在の操作対象フォルダーに対するすべての入力を取り消します\n : " (expand-file-name "./MP3") default-directory)))
              (setq output-dir (my-read-str (format " 出力先フォルダーのパスを入力 （デフォルトは \"%s\" ）\n 相対パスは \"%s\" を基準に入力してください\n vcw-stop と入力すると現在の操作対象フォルダーに対するすべての入力を取り消します\n : " (expand-file-name "./Sony Walkman") default-directory))))
            (if (string= "" (format "%s" output-dir))
                (if (string= "3" (format "%s" input-mode))
                    (setq output-dir (expand-file-name "MP3" target-dir))
                  (setq output-dir (expand-file-name "Sony Walkman" target-dir)))
              (setq output-dir (expand-file-name output-dir)))
            (while (string= (expand-file-name output-dir) (expand-file-name target-dir))
              (if (string= "3" (format "%s" input-mode))
                  (setq output-dir (my-read-str (format " 操作対象フォルダーとは別のフォルダーを指定してください （デフォルトは \"%s\" ）\n 相対パスは \"%s\" を基準に入力してください\n vcw-stop と入力すると現在の操作対象フォルダーに対するすべての入力を取り消します\n : " (expand-file-name "./MP3") default-directory)))
                (setq output-dir (my-read-str (format " 操作対象フォルダーとは別のフォルダーを指定してください （デフォルトは \"%s\" ）\n 相対パスは \"%s\" を基準に入力してください\n vcw-stop と入力すると現在の操作対象フォルダーに対するすべての入力を取り消します\n : " (expand-file-name "./Sony Walkman") default-directory))))
              (if (string= "" (format "%s" output-dir))
                  (if (string= "3" (format "%s" input-mode))
                      (setq output-dir (expand-file-name "MP3" target-dir))
                    (setq output-dir (expand-file-name "Sony Walkman" target-dir)))
                (setq output-dir (expand-file-name output-dir))))
            (princ "\n")
            ;; 入力をやり直す場合
            (when (string= "vcw-stop" (file-name-nondirectory output-dir))
              (my-princ (format "\n \"%s\" に対する操作を中断しました\n\n" target-dir))
              (princ " \n ----------\n\n")
              ;; 各種変数初期化
              (setq target-dir nil)       ; 対象ディレクトリ
              (setq input-mode nil)           ; モード
              (setq input-mode-in-mode nil)   ; モード内モード
              (setq output-dir nil)       ; 出力先ディレクトリ
              (setq conv-all-files-or-not nil) ; 全ファイル変換フラグ
              (throw 'vcw-ask-retry t))
            (my-princ (format " 出力先フォルダーを \"%s\" に設定しました\n\n" output-dir))
            (cd current-dir-path)
            ;; 変換ファイルの対象指定
            (let ((answer-conv-all-files-or-not nil))
              (if (string= "3" (format "%s" input-mode))
                  (setq answer-conv-all-files-or-not (my-read-str " 動画や音声ファイル以外のファイルも変換しますか？\n （何かしら入力すると、すべてのファイルが変換対象となります）\n ただし、vcw-stop と入力すると、現在操作対象となっているフォルダーに対するすべての入力を取り消します\n : "))
                (setq answer-conv-all-files-or-not (my-read-str " 動画ファイル以外のファイルも変換しますか？\n （何かしら入力すると、すべてのファイルが変換対象となります）\n ただし、vcw-stop と入力すると、現在操作対象となっているフォルダーに対するすべての入力を取り消します\n : ")))
              (princ "\n")
              ;; 入力をやり直す場合
              (when (string= "vcw-stop" (format "%s" answer-conv-all-files-or-not))
                (my-princ (format "\n \"%s\" に対する操作を中断しました\n\n" target-dir))
                (princ " \n ----------\n\n")
                ;; 各種変数初期化
                (setq target-dir nil)       ; 対象ディレクトリ
                (setq input-mode nil)           ; モード
                (setq input-mode-in-mode nil)   ; モード内モード
                (setq output-dir nil)       ; 出力先ディレクトリ
                (setq conv-all-files-or-not nil) ; 全ファイル変換フラグ
                (throw 'vcw-ask-retry t))
              (if (string= "" answer-conv-all-files-or-not)
                  (setq conv-all-files-or-not nil)
                (setq conv-all-files-or-not t)))
            (princ "\n ----------\n\n")
            ;; 各種設定を格納したリストの更新
            (setq vcw-config-list (cons (list target-dir input-mode input-mode-in-mode output-dir conv-all-files-or-not) vcw-config-list))
            ;; 各種変数初期化
            (setq target-dir nil)       ; 対象ディレクトリ
            (setq input-mode nil)           ; モード
            (setq input-mode-in-mode nil)   ; モード内モード
            (setq output-dir nil)       ; 出力先ディレクトリ
            (setq conv-all-files-or-not nil)))) ; 全ファイル変換フラグ
      ;; 設定リストの整理（逆順に）
      (setq vcw-config-list (nreverse vcw-config-list))
      ;; 変換開始時刻記録
      (setq start-time (string-to-number (format-time-string "%s")))
      ;; 変換開始メッセージ
      (my-princ "\n 変換開始！\n\n")
      ;; 設定に従って各種変換操作開始
      (let ((cnv-config-target nil)
            (cnv-target-dir nil)
            (cnv-mode nil)
            (cnv-mode-in-mode nil)
            (cnv-output-dir nil)
            (cnv-all-files-flag nil)
            (cnv-result nil))
        (while vcw-config-list
          (setq cnv-config-target (car vcw-config-list))
          (setq cnv-target-dir (nth 0 cnv-config-target))
          (setq cnv-mode (nth 1 cnv-config-target))
          (setq cnv-mode-in-mode (nth 2 cnv-config-target))
          (setq cnv-output-dir (nth 3 cnv-config-target))
          (setq cnv-all-files-flag (nth 4 cnv-config-target))
          (if (string= "1" cnv-mode)
              (setq cnv-result (conv2mp4-main cnv-target-dir cnv-output-dir vcw-bitrate-normal nil cnv-all-files-flag))
            (if (string= "2" cnv-mode)
                (setq cnv-result (conv2mp4-main cnv-target-dir cnv-output-dir vcw-bitrate-lq nil cnv-all-files-flag))
              (if (string= "3" cnv-mode)
                  (setq cnv-result (conv2mp3-main cnv-target-dir cnv-output-dir cnv-all-files-flag))
                (if (string= "4" cnv-mode)
                    (if (string= "1" cnv-mode-in-mode)
                        (setq cnv-result (conv2mp4-main cnv-target-dir cnv-output-dir vcw-bitrate-normal t cnv-all-files-flag))
                      (setq cnv-result (conv2mp4-main cnv-target-dir cnv-output-dir vcw-bitrate-lq t cnv-all-files-flag)))))))
          (setq converted-files-count (+ converted-files-count (nth 0 cnv-result)))
          (setq error-files-count (+ error-files-count (nth 1 cnv-result)))
          (setq cnv-config-target nil)
          (setq cnv-target-dir nil)
          (setq cnv-mode nil)
          (setq cnv-mode-in-mode nil)
          (setq cnv-output-dir nil)
          (setq cnv-all-files-flag nil)
          (if (equal nil vcw-stop-flag)
              (setq vcw-config-list (cdr vcw-config-list))
            (setq vcw-config-list nil))))
      ;; 変換結果の出力
      (my-princ (format "\n 変換終了！\n 変換済みファイル数 : %s\n エラーファイル数 : %s\n 経過時間 : %s\n\n"
                        converted-files-count
                        error-files-count
                        (my-calc-time-taken start-time (string-to-number (format-time-string "%s")))))
      ;; 作業前ディレクトリに戻る
      (cd current-dir-path))))

(defun conv2mp4-main (target-dir output-dir bitrate rotate-flag conv-all-files-flag)
  "動画変換モード"
  (let ((encoder-name nil)
        (remaining-files-list nil)
        (conv-result nil)
        (converted-files-count 0)
        (error-files-count 0)
        (error-filename nil))
    (catch 'conv2mp4-end
      ;; 変換対象ディレクトリへ移動、無ければ終了
      ;; 対象がディレクトリでなかった場合も終了
      (if (and (file-directory-p target-dir) (file-exists-p target-dir))
          (cd target-dir)
        (throw 'conv2mp4-end t))
      ;; エンコーダー設定
      (unless (ignore-errors
                (setq encoder-name (find-encoder))
                t)
        (throw 'conv2mp4-end t))
      ;; ログファイル初期化
      (if (equal nil rotate-flag)
          (output-log-init vcw-log-file output-dir (format "MP4_%s" bitrate))
        (output-log-init vcw-log-file output-dir (format "MP4_%s_rotate" bitrate)))
      ;; 変換操作ループ
      (while t
        ;; 各種必要ディレクトリ作成
        (unless (file-exists-p output-dir)
          (make-directory output-dir t))
        (unless (file-exists-p vcw-dst-dir-original)
          (make-directory vcw-dst-dir-original t))
        ;; 変換対象ファイルのリストを作成
        (if (equal nil conv-all-files-flag)
            (setq remaining-files-list (list-remaining-files vcw-video-ext-list))
          (setq remaining-files-list (my-exclude-invalid-file (directory-files ".")))
          (let (non-dir-list)
            (while remaining-files-list
              (unless (file-directory-p (car remaining-files-list)) ; ディレクトリのときは除外
                (unless (string= "txt" (file-name-extension (car remaining-files-list))) ; テキストファイルのときは除外
                  (setq non-dir-list (cons (car remaining-files-list) non-dir-list))))
              (setq remaining-files-list (cdr remaining-files-list)))
            (setq remaining-files-list (nreverse non-dir-list))))
        ;; 終了条件（変換対象ファイルリストが空のとき終了）
        (when (= 0 (length remaining-files-list))
          (throw 'conv2mp4-end t))
        ;; 残りファイル数表示
        (my-princ (format "\n 残り %s ファイル （ %s フォルダー）\n\n" (length remaining-files-list) (length vcw-config-list)))
        ;; 変換ファイル名表示
        (if (equal nil rotate-flag)
            (my-princ (format " \"%s\"\n を MP4_%s に変換中 ... \n\n" (car remaining-files-list) bitrate))
          (my-princ (format " \"%s\"\n を MP4_%s_rotate に変換中 ... \n\n" (car remaining-files-list) bitrate)))
        ;; ログファイル記録
        (output-log vcw-log-file (format "%s | %s" (my-time) (car remaining-files-list)))
        ;; 動画変換
        (setq conv-result (conv2mp4 (car remaining-files-list) output-dir encoder-name bitrate rotate-flag))
        ;; 変換を中断したときは強制終了
        (when (string= "t" (format "%s" vcw-stop-flag))
          (throw 'conv2mp4-end t))
        ;; 変換結果にしたがって後処理
        (if (string= "t" (format "%s" conv-result))
            ;; 変換に成功したとき
            (progn
              ;; 変換前ファイルの移動
              (vcw-rename-file (car remaining-files-list) (format "./%s/%s" vcw-dst-dir-original (car remaining-files-list)))
              (setq converted-files-count (1+ converted-files-count)))
          ;; 変換に失敗したとき
          ;; エラーを通知
          (my-princ (format " \"%s\"\n の変換に失敗しました\n\n" (car remaining-files-list)))
          ;; エラーディレクトリの作成
          (unless (and (file-exists-p vcw-dst-dir-error) (file-directory-p vcw-dst-dir-error))
            (make-directory (format "./%s" vcw-dst-dir-error)))
          ;; 変換前ファイルの移動
          (setq error-filename (vcw-rename-file (car remaining-files-list) (format "./%s/%s" vcw-dst-dir-error (car remaining-files-list))))
          ;; エラーログ記録
          (output-log (format "%s/%s\n" vcw-dst-dir-error vcw-error-log-file) error-filename)
          (setq error-files-count (1+ error-files-count)))))
    (list converted-files-count error-files-count)))

(defun conv2mp3-main (target-dir output-dir conv-all-files-flag)
  "音声変換モード"
  (let ((remaining-files-list nil)
        (conv-result nil)
        (converted-files-count 0)
        (error-files-count 0)
        (error-filename nil))
    (catch 'conv2mp3-end
      ;; 変換対象ディレクトリへ移動、無ければ終了
      (if (and (file-directory-p target-dir) (file-exists-p target-dir))
          (cd target-dir)
        (throw 'conv2mp3-end t))
      ;; ログファイル初期化
      (output-log-init vcw-log-file output-dir "MP3")
      ;; 変換操作ループ
      (while t
        ;; 各種必要ディレクトリ作成
        (unless (file-exists-p output-dir)
          (make-directory output-dir t))
        (unless (file-exists-p vcw-dst-dir-original)
          (make-directory vcw-dst-dir-original t))
        ;; 変換対象ファイルのリストを作成
        (if (equal nil conv-all-files-flag)
            (setq remaining-files-list (list-remaining-files (append vcw-video-ext-list vcw-audio-ext-list)))
          (setq remaining-files-list (my-exclude-invalid-file (directory-files ".")))
          (let (non-dir-list)
            (while remaining-files-list
              (unless (file-directory-p (car remaining-files-list)) ; ディレクトリのときは除外
                (unless (string= "txt" (file-name-extension (car remaining-files-list))) ; テキストファイルのときは除外
                  (setq non-dir-list (cons (car remaining-files-list) non-dir-list))))
              (setq remaining-files-list (cdr remaining-files-list)))
            (setq remaining-files-list (nreverse non-dir-list))))
        ;; 終了条件（変換対象ファイルリストが空のとき終了）
        (when (= 0 (length remaining-files-list))
          (throw 'conv2mp3-end t))
        ;; 残りファイル数表示
        (my-princ (format "\n 残り %s ファイル （ %s フォルダー）\n\n" (length remaining-files-list) (length vcw-config-list)))
        ;; 変換ファイル名表示
        (my-princ (format " \"%s\"\n を MP3 に変換中 ... \n\n" (car remaining-files-list)))
        ;; ログファイル記録
        (output-log vcw-log-file (format "%s | %s\n" (my-time) (car remaining-files-list)))
        ;; 音声変換
        (setq conv-result (conv2mp3 (car remaining-files-list) output-dir))
        ;; 変換を中断したときは強制終了
        (when (string= "t" (format "%s" vcw-stop-flag))
          (throw 'conv2mp3-end t))
        ;; 変換結果にしたがって後処理
        (if (string= "t" (format "%s" conv-result))
            ;; 変換に成功したとき
            (progn
              ;; 変換前ファイルの移動
              (vcw-rename-file (car remaining-files-list) (format "./%s/%s" vcw-dst-dir-original (car remaining-files-list)))
              (setq converted-files-count (1+ converted-files-count)))
          ;; 変換に失敗したとき
          ;; エラーを通知
          (my-princ (format " \"%s\"\n の変換に失敗しました\n\n" (car remaining-files-list)))
          ;; エラーディレクトリの作成
          (unless (and (file-exists-p vcw-dst-dir-error) (file-directory-p vcw-dst-dir-error))
            (make-directory (format "./%s" vcw-dst-dir-error)))
          ;; 変換前ファイルの移動
          (setq error-filename (vcw-rename-file (car remaining-files-list) (format "./%s/%s" vcw-dst-dir-error (car remaining-files-list))))
          ;; エラーログ記録
          (output-log (format "%s/%s\n" vcw-dst-dir-error vcw-error-log-file) error-filename)
          (setq error-files-count (1+ error-files-count)))))
    (list converted-files-count error-files-count)))

(defun conv2mp4 (filename output-dir encoder-name bitrate rotate-flag)
  "動画変換関数
'filename' にはパスではなくファイル名単体を渡すこと、パスが含まれる場合は本関数の実行前に該当パスへ移動すること
'filename' ファイルに音声が含まれない場合は、音声無しのまま動画変換を進める（conv2mp3 との違い）"
  (let ((filename-body nil)
        (filename-ext nil)
        (file-frame-rate 0)
        (rotate-arg nil)
        (audio-map-arg nil)
        (result nil))
    ;; 回転の有無により引数を変える
    (if (equal t rotate-flag)
        (setq rotate-arg "transpose=2, ")
      (setq rotate-arg ""))
    ;; ファイル名本体を取得する
    (setq filename-body (file-name-sans-extension filename))
    ;; ファイルの拡張子を取得する
    (setq filename-ext (file-name-extension filename))
    ;; ファイルのリネーム（Emacsとffmpeg・ffprobeの内部文字コードの違いによるエラーを防ぐため）
    (if (string= "nil" (format "%s" filename-ext))
        (rename-file filename ".#")
      (rename-file filename (format ".#.%s" filename-ext)))
    ;; 指定動画ファイルのフレームレートの取得
    ;; 波ダッシュ・全角チルダ問題や全角ダッシュ問題等に対応するため（ffmpeg・ffprobe へ引数を渡す際にエラーが起こる）、リネーム後のこの段階で本操作を行う
    (with-temp-buffer
      (if (string= "nil" (format "%s" filename-ext))
          (insert (my-shell-command-to-string "ffprobe \".#\""))
        (insert (my-shell-command-to-string (format "ffprobe \".#.%s\"" filename-ext))))
      (goto-char (point-min))
      (when (re-search-forward ", \\([0-9]+[.]?[0-9]*\\) fps" nil t)
        (setq file-frame-rate (buffer-substring (match-beginning 1) (match-end 1)))))
    ;; 音声の有無を調べる
    (let ((stream-result nil))
      (if (string= "nil" (format "%s" filename-ext))
          (setq stream-result (my-shell-command-to-string "ffprobe -i \".#\" -show_streams -select_streams a -loglevel error"))
        (setq stream-result (my-shell-command-to-string (format "ffprobe -i \".#.%s\" -show_streams -select_streams a -loglevel error" filename-ext))))
      (if (string= "" (format "%s" stream-result))
          (progn
            (setq audio-map-arg "")
            (output-log vcw-log-file " （ no audio ）\n"))
        (setq audio-map-arg " -map 0:1")
        (output-log vcw-log-file "\n")))
    ;; 変換操作
    (if (ignore-errors
          (if (and (< 0 (string-to-number file-frame-rate)) (> 25 (string-to-number file-frame-rate)))
              ;; フレームレートが 25 未満（かつ 0 より大きい）のとき
              (progn
                (if (string= "nil" filename-ext)
                    ;; 拡張子がないとき
                    (my-start-process-shell-command "vcw" "vcw" (format "ffmpeg -noautorotate -i \".#\" -map 0:0%s -vf \"%sscale=w=trunc(ih*dar/2)*2:h=trunc(ih/2)*2, setsar=1/1, scale=w=320:h=240:force_original_aspect_ratio=1, pad=w=320:h=240:x=(ow-iw)/2:y=(oh-ih)/2:color=#000000, fps=%s\" -pix_fmt yuv420p -y -ar 44100 -ac 2 -c:a aac -b:a 128k -profile:a 1 -c:v %s -b:v %sk -profile:v baseline -threads 0 \"%s\\.#.mp4\"" audio-map-arg rotate-arg file-frame-rate encoder-name bitrate output-dir))
                  ;; 拡張子があるとき
                  (my-start-process-shell-command "vcw" "vcw" (format "ffmpeg -noautorotate -i \".#.%s\" -map 0:0%s -vf \"%sscale=w=trunc(ih*dar/2)*2:h=trunc(ih/2)*2, setsar=1/1, scale=w=320:h=240:force_original_aspect_ratio=1, pad=w=320:h=240:x=(ow-iw)/2:y=(oh-ih)/2:color=#000000, fps=%s\" -pix_fmt yuv420p -y -ar 44100 -ac 2 -c:a aac -b:a 128k -profile:a 1 -c:v %s -b:v %sk -profile:v baseline -threads 0 \"%s\\.#.mp4\"" filename-ext audio-map-arg rotate-arg file-frame-rate encoder-name bitrate output-dir))))
            ;; フレームレートが 25 以上のとき
            (if (string= "nil" filename-ext)
                ;; 拡張子がないとき
                (my-start-process-shell-command "vcw" "vcw" (format "ffmpeg -noautorotate -i \".#\" -map 0:0%s -vf \"%sscale=w=trunc(ih*dar/2)*2:h=trunc(ih/2)*2, setsar=1/1, scale=w=320:h=240:force_original_aspect_ratio=1, pad=w=320:h=240:x=(ow-iw)/2:y=(oh-ih)/2:color=#000000, fps=%s\" -pix_fmt yuv420p -y -ar 44100 -ac 2 -c:a aac -b:a 128k -profile:a 1 -c:v %s -b:v %sk -profile:v baseline -threads 0 \"%s\\.#.mp4\"" audio-map-arg "25000/1000" rotate-arg encoder-name bitrate output-dir))
              ;; 拡張子があるとき
              (my-start-process-shell-command "vcw" "vcw" (format "ffmpeg -noautorotate -i \".#.%s\" -map 0:0%s -vf \"%sscale=w=trunc(ih*dar/2)*2:h=trunc(ih/2)*2, setsar=1/1, scale=w=320:h=240:force_original_aspect_ratio=1, pad=w=320:h=240:x=(ow-iw)/2:y=(oh-ih)/2:color=#000000, fps=%s\" -pix_fmt yuv420p -y -ar 44100 -ac 2 -c:a aac -b:a 128k -profile:a 1 -c:v %s -b:v %sk -profile:v baseline -threads 0 \"%s\\.#.mp4\"" filename-ext audio-map-arg rotate-arg "25000/1000" encoder-name bitrate output-dir))))
          (catch 'conv2mp4-stop
            (while t
              (sit-for 1)
              (when (or (file-exists-p "./vcw-stop") (file-exists-p "./vcw-stop.txt"))
                (delete-process "vcw")
                (setq vcw-stop-flag t)
                (sit-for 1)
                (throw 'conv2mp4-stop t))
              (unless (get-process "vcw")
                (throw 'conv2mp4-stop t))))
          t)
        ;; 変換後の後始末
        ;; 変換が正常に終了したとき
        (progn
          (if (string= "t" (format "%s" vcw-stop-flag))
              ;; 変換を中断したとき
              (progn
                ;; 変換前ファイルのリネーム
                (if (string= "nil" (format "%s" filename-ext))
                    (rename-file ".#" filename)
                  (rename-file (format ".#.%s" filename-ext) filename))
                ;; 変換後の中途半端なファイルがあれば削除
                (when (file-exists-p (format "%s/.#.mp4" output-dir))
                  (delete-file (format "%s/.#.mp4" output-dir)))
                (setq result nil))
            ;; 変換が完了していた（中断していない）とき
            (if (file-exists-p (format "%s/.#.mp4" output-dir))
                ;; 変換が実際に進んでいたとき
                (progn
                  ;; 変換前ファイルのリネーム
                  (if (string= "nil" (format "%s" filename-ext))
                      (rename-file ".#" filename)
                    (rename-file (format ".#.%s" filename-ext) filename))
                  ;; 変換後ファイルのリネーム
                  (vcw-rename-file (format "%s/.#.mp4" output-dir) (format "%s/%s.mp4" output-dir filename-body))
                  (setq result t))
              ;; 変換が実際は進んでいなかったとき
              ;; 変換前ファイルのリネーム
              (if (string= "nil" (format "%s" filename-ext))
                  (rename-file ".#" filename)
                (rename-file (format ".#.%s" filename-ext) filename))
              ;; 変換後の中途半端なファイルがあれば削除
              (when (file-exists-p (format "%s/.#.mp4" output-dir))
                (delete-file (format "%s/.#.mp4" output-dir)))
              (setq result nil))))
      ;; 変換が異常終了したとき
      ;; 変換前ファイルのリネーム
      (if (string= "nil" (format "%s" filename-ext))
          (rename-file ".#" filename)
        (rename-file (format ".#.%s" filename-ext) filename))
      ;; 変換後の中途半端なファイルがあれば削除
      (when (file-exists-p (format "%s/.#.mp4" output-dir))
        (delete-file (format "%s/.#.mp4" output-dir)))
      (setq result nil))
    result))

(defun conv2mp3 (filename output-dir)
  "音声変換関数
'filename' にはパスではなくファイル名単体を渡すこと、パスが含まれる場合は本関数の実行前に該当パスへ移動すること
'filename' ファイルに音声が含まれていない場合は nil を返す"
  (let ((filename-body nil)
        (filename-ext nil)
        (interlace-flag nil)
        (result nil))
    ;; ファイル名本体を取得する
    (setq filename-body (file-name-sans-extension filename))
    ;; ファイルの拡張子を取得する
    (setq filename-ext (file-name-extension filename))
    ;; ファイルのリネーム（Emacsとffmpegの内部文字コードの違いによるエラーを防ぐため）
    (if (string= "nil" (format "%s" filename-ext))
        (rename-file filename ".#")
      (rename-file filename (format ".#.%s" filename-ext)))
    ;; インターレースかプログレッシブかの判別
    (if (string= "nil" filename-ext)
        (setq interlace-flag (judge-interlace-or-not ".#"))
      (setq interlace-flag (judge-interlace-or-not (format ".#.%s" filename-ext))))
    ;; 変換操作
    (if (ignore-errors
          (if (string= "t" (format "%s" interlace-flag))
              ;; インターレースのとき
              (progn
                (if (string= "nil" filename-ext)
                    ;; 拡張子がないとき
                    (my-start-process-shell-command "vcw" "vcw" (format "ffmpeg -noautorotate -i \".#\" -vf \"kerndeint\" -y -vn -c:a libmp3lame -ab 128k -ar 44100 -ac 2  -f mp3 \"%s\\.#.mp3\"" output-dir))
                  ;; 拡張子があるとき
                  (my-start-process-shell-command "vcw" "vcw" (format "ffmpeg -noautorotate -i \".#.%s\" -vf \"kerndeint\" -y -vn -c:a libmp3lame -ab 128k -ar 44100 -ac 2  -f mp3 \"%s\\.#.mp3\"" filename-ext output-dir))))
            ;; プログレッシブのとき
            (if (string= "nil" filename-ext)
                ;; 拡張子がないとき
                (my-start-process-shell-command "vcw" "vcw" (format "ffmpeg -noautorotate -i \".#\" -y -vn -c:a libmp3lame -ab 128k -ar 44100 -ac 2  -f mp3 \"%s\\.#.mp3\"" output-dir))
              ;; 拡張子があるとき
              (my-start-process-shell-command "vcw" "vcw" (format "ffmpeg -noautorotate -i \".#.%s\" -y -vn -c:a libmp3lame -ab 128k -ar 44100 -ac 2  -f mp3 \"%s\\.#.mp3\"" filename-ext output-dir))))
          (catch 'conv2mp3-stop
            (while t
              (sit-for 1)
              (when (or (file-exists-p "./vcw-stop") (file-exists-p "./vcw-stop.txt"))
                (delete-process "vcw")
                (setq vcw-stop-flag t)
                (sit-for 1)
                (throw 'conv2mp3-stop t))
              (unless (get-process "vcw")
                (throw 'conv2mp3-stop t))))
          t)
        ;; 変換後の後始末
        ;; 変換が正常に終了したとき
        (progn
          (if (string= "t" (format "%s" vcw-stop-flag))
              ;; 変換を中断したとき
              (progn
                ;; 変換前ファイルのリネーム
                (if (string= "nil" (format "%s" filename-ext))
                    (rename-file ".#" filename)
                  (rename-file (format ".#.%s" filename-ext) filename))
                ;; 変換後の中途半端なファイルがあれば削除
                (when (file-exists-p (format "%s/.#.mp3" output-dir))
                  (delete-file (format "%s/.#.mp3" output-dir)))
                (setq result nil))
            ;; 変換が完了していた（中断していない）とき
            (if (file-exists-p (format "%s/.#.mp3" output-dir))
                ;; 変換が実際に進んでいたとき
                (progn
                  ;; 変換前ファイルのリネーム
                  (if (string= "nil" (format "%s" filename-ext))
                      (rename-file ".#" filename)
                    (rename-file (format ".#.%s" filename-ext) filename))
                  ;; 変換後ファイルのリネーム
                  (vcw-rename-file (format "%s/.#.mp3" output-dir) (format "%s/%s.mp3" output-dir filename-body))
                  (setq result t))
              ;; 変換が実際は進んでいなかったとき
              ;; 変換前ファイルのリネーム
              (if (string= "nil" (format "%s" filename-ext))
                  (rename-file ".#" filename)
                (rename-file (format ".#.%s" filename-ext) filename))
              ;; 変換後の中途半端なファイルがあれば削除
              (when (file-exists-p (format "%s/.#.mp3" output-dir))
                (delete-file (format "%s/.#.mp3" output-dir)))
              (setq result nil))))
      ;; 変換が異常終了したとき
      ;; 変換前ファイルのリネーム
      (if (string= "nil" (format "%s" filename-ext))
          (rename-file ".#" filename)
        (rename-file (format ".#.%s" filename-ext) filename))
      ;; 変換後の中途半端なファイルがあれば削除
      (when (file-exists-p (format "%s/.#.mp3" output-dir))
        (delete-file (format "%s/.#.mp3" output-dir)))
      (setq result nil))
    result))

(defun find-encoder ()
  "使用できるエンコーダーを返す
nvenc が使える場合は 'h264_nvenc' を返し、そうでない場合は 'libx264' を返す"
  (let ((result nil))
    (with-temp-buffer
      (insert (my-shell-command-to-string "ffmpeg -encoders"))
      (goto-char (point-min))
      (if (search-forward "V..... h264_nvenc" nil t)
          (setq result "h264_nvenc")
        (setq result "libx264")))
    result))

(defun list-remaining-files (file-ext-list)
  "変換予定のファイルのリストを返す"
  (let ((all-files nil)
        (ext-list nil)
        (result nil))
    (setq all-files (directory-files "./"))
    (while all-files
      (setq ext-list file-ext-list)
      (with-temp-buffer
        (insert (car all-files))
        (catch 'judge-ext-end
          (while ext-list
            (if (search-backward (format ".%s" (car ext-list)) nil t)
                (progn
                  (setq result (cons (car all-files) result))
                  (throw 'judge-ext-end t)))
            (setq ext-list (cdr ext-list)))))
      (setq all-files (cdr all-files)))
    (setq result (reverse result))
    result))

(defun vcw-rename-file (old-filename new-filename)
  "ファイル名の文字数の関係でリネーム時にたまにエラーが生じるため、そのエラーを回避しつつリネームする関数
リネームに成功すればそのまま移動後のファイル名を返し、失敗した時は成功するまで「ファイル名から1文字削除して再挑戦」を繰り返した後、成功時のファイル名を返す
返すファイル名は非ディレクトリパートのみ"
  (let ((filename-newest new-filename)
        (filename-final nil)
        (result nil))
    ;; 成功するまでリネーム
    (while (not (ignore-errors
                  (setq filename-final (my-find-new-filename filename-newest))
                  (rename-file old-filename filename-final)
                  t))
      ;; エラー時処理
      (with-temp-buffer
        ;; ファイル名から最後の1文字を消す
        (insert (file-name-sans-extension filename-newest))
        (delete-char -1)
        (if (string= "nil" (file-name-extension filename-newest))
            ;; 拡張子なしの場合
            (setq filename-newest (buffer-substring (point) (progn (beginning-of-line) (point))))
          ;; 拡張子ありの場合
          (setq filename-newest (format "%s.%s" (buffer-substring (point) (progn (beginning-of-line) (point))) (file-name-extension filename-newest))))))
    ;; リネーム後のファイル名（非ディレクトリパート）を返す
    (setq result (file-name-nondirectory filename-final))
    result))

(defun output-log (log-filename contents)
  "'log-filename'ログファイルに'contents'を書き込む"
  (find-file log-filename)
  (setq require-final-newline nil)
  (goto-char (point-max))
  (insert (format "%s" contents))
  (my-save-buffer)
  (kill-buffer (current-buffer))
  (my-del-extra-file log-filename))

(defun output-log-init (log-filename output-dir target-format)
  "'log-filename'ログファイルに対して日時を書き込む等の初期化処理を行う"
  (find-file log-filename)
  (goto-char (point-max))
  (if (= (point-min) (point-max))
      (output-log log-filename (format "%s （ %s ）\n" output-dir target-format))
    (output-log log-filename (format "\n\n%s （ %s ）\n" output-dir target-format))))

(defun read-mode (str mode-list read-mode-quit-flag)
  "リスト'mode-list'に番号をつけて提示し、適切な数字を入力されたらその数字を返す
'read-mode-quit-flag' は、選択肢の出力時に 'Quit' の項目を付け足すかどうかの判別を行う"
  (let ((result 0))
    (while (not (or (and (string= "t" (format "%s" read-mode-quit-flag))
                         (string= "q" (format "%s" result)))
                    (and (<= 1 (string-to-number (format "%s" result)))
                         (<= (string-to-number (format "%s" result)) (length mode-list)))))
      (unless (equal nil str)
        (my-princ (format "%s\n" str)))
      (let ((mode-number (length mode-list))
            (counter 0))
        (while (< counter mode-number)
          (my-princ (format " %s) %s" (1+ counter) (nth counter mode-list)))
          (when (= counter 0)
            (my-princ " （デフォルト）"))
          (princ "\n")
          (setq counter (1+ counter)))
        (when (string= "t" (format "%s" read-mode-quit-flag))
          (princ " q) Quit\n")))
      (setq result (read-string " : "))
      (when (string= "" result)
        (setq result "1")))
    result))

(defun judge-interlace-or-not (filename)
  "指定動画ファイルがインターレースかそうでないか（プログレッシブか）を判別する"
  (let ((tff 0)
        (bff 0)
        (progressive 0)
        (ff 0)
        (threshold 0.2)
        (result nil))
    (with-temp-buffer
      (insert (my-shell-command-to-string (format "ffmpeg -i \"%s\" -vf idet -an -sn -f null -" filename)))
      (goto-char (point-min))
      (when (search-forward "Multi frame detection:" nil t)
        (when (re-search-forward "TFF:[ ]+\\([0-9]+\\) " nil t)
          (setq tff (string-to-number (buffer-substring (match-beginning 1) (match-end 1))))
          (when (re-search-forward "BFF:[ ]+\\([0-9]+\\) " nil t)
            (setq bff (string-to-number (buffer-substring (match-beginning 1) (match-end 1))))
            (when (re-search-forward "Progressive:[ ]\\(+[0-9]+\\) " nil t)
              (setq progressive (string-to-number (buffer-substring (match-beginning 1) (match-end 1))))
              (setq ff (+ tff bff))
              (if (> (/ ff (+ ff progressive)) threshold)
                  (setq result t)
                (setq result nil)))))))
    result))

(defun my-princ (str)
  "標準出力関数"
  (my-print str vcw-lib-path))

(defun my-read-str (str)
  "標準入力関数"
  (my-read-string str vcw-lib-path))

(main)
;;; vcwalk.el ends here
