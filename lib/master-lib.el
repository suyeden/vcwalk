;;; master-lib.el --- collection of useful elisp functions -*- Emacs-Lisp -*-

;; Copyright (C) 2021 suyeden

;; Author: suyeden
;; Version: 1.0.0
;; Keywords: lisp, extensions, convenience
;; Package-Requires: ((emacs "27.1"))

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

;; master-lib は、すえーでんが作成した、便利な自作 Emacs Lisp 関数をまとめたライブラリです。
;; 主に Windows マシン上で、 '--script' オプションを用いるときに利用されることを想定しています。
;;
;; 'master-lib.el' is the collection of useful Emacs Lisp functions written by suyeden.
;; This program is mainly intended for use in scripts which run with Batch Mode ('--script' option) from command line.

;;; Code:

;; eprintf.dll を使う場合は本ライブラリと同じディレクトリ内に配置する
(when (file-exists-p (expand-file-name "eprintf.dll" (format "%s/../" load-file-name)))
  (load (expand-file-name "eprintf.dll" (format "%s/../" load-file-name)) nil t))

(defun my-init ()
  "バッチモードで起動することを想定したスクリプトの先頭で呼び出す関数
本ライブラリ中の関数を利用する場合は必ずスクリプト先頭でロードすること"
  (if (string= "windows-nt" (format "%s" system-type))
      (progn
        (set-language-environment "Japanese")
        (prefer-coding-system 'utf-8)
        (set-file-name-coding-system 'cp932)
        (set-keyboard-coding-system 'cp932)
        (set-terminal-coding-system 'cp932)
        (set-default 'buffer-file-coding-system 'utf-8)
        (setq locale-coding-system 'cp932)
        ;; 標準（エラー）出力への出力時における波ダッシュ・全角チルダ問題への対処
        (coding-system-put 'cp932 :encode-translation-table
                           (get 'japanese-ucs-jis-to-cp932-map 'translation-table)))
    (set-language-environment "Japanese")
    (prefer-coding-system 'utf-8)
    (set-file-name-coding-system 'utf-8)
    (set-keyboard-coding-system 'utf-8)
    (set-terminal-coding-system 'utf-8)
    (set-default 'buffer-file-coding-system 'utf-8)
    (setq locale-coding-system 'utf-8)))

(defun my-save-buffer ()
  "文字コードをutf-8に指定してカレントバッファを保存する
本関数はバッファ内容に変更があれば適用され、一度他の文字コードで保存されたバッファ（ファイル）であったとしても utf-8 として保存してくれる
なお、DOS窓（文字コードが cp932）から渡される入力値は文字コード変換が行われていない raw-text であり、raw-text を含んだバッファは保存の度にバッファ内文字列に対して文字コード変換が行われるため、そのままバッファ（ファイル）内に挿入すると既に文字コード変換が行われている文字列に対しても文字コード変換が行われてしまい、文字化けが起こる
また、raw-text の文字コード変換の際には文字コードの指定が効かず、指定しても「DOS窓（文字コードが cp932）から渡された raw-text なら cp932 に変換」というような変換が自動でなされる（指定しなかった場合は使用する文字コードを聞かれる）
したがって、raw-text をそのまま挿入したようなバッファに対して本関数を適用した場合、期待した動きを見せてくれない（上記のようなDOS窓からの入力値の場合、utf-8 ではなく cp932 として保存される上に、編集前に存在した文字列に対しては文字化けが起こる）
DOS窓から得た入力値のような raw-text をバッファ内に挿入する場合は、入力値を一時ファイルに挿入・保存するなどして一度入力値を何らかの文字コードに変換してから、該当文字列をコピーすることで、スムーズな文字コード変換・移行が行われるようになる
これはバッファへの挿入や保存といった場面だけでなく、関数の引数として渡したりするような場合においても有効な手段である"
  (let ((coding-system-for-write 'utf-8))
    (save-buffer)))

(defun my-read-string (str eprintf-dir-path)
  "raw-text対策用入力関数
質問として出力したい文字列と、eprintf.dll のあるディレクトリのパスを指定する
コマンドプロンプトから入力値を得るようなケース（raw-text のやり取りがあるケース）において重宝する"
  (let ((current-coding-system nil)
        (filename nil))
    (let ((result nil))
    (if (string= "windows-nt" (format "%s" system-type))
        (let ((my-answer nil)
              (my-tmp-file nil))
          ;; とりあえず入力値の文字コード変換
          (my-print str eprintf-dir-path)
          (setq my-answer (read-string ""))
          (setq my-tmp-file (format ".my-read-str-%s.txt" (eval (cons '+ (current-time)))))
          (find-file my-tmp-file)
          (insert my-answer)
          (let ((coding-system-for-write 'utf-8))
            (save-buffer))
          (kill-buffer (current-buffer))
          (my-del-extra-file my-tmp-file)
          ;; 入力値の再取得
          (find-file my-tmp-file)
          (goto-char (point-min))
          (setq result (buffer-substring (point) (progn (end-of-line) (point))))
          (kill-buffer (current-buffer))
          (delete-file my-tmp-file)
          (my-del-extra-file my-tmp-file))
      (setq result (read-string (format "%s" str))))
    result)))

(defun my-shell-command-to-string (arg)
  "シェルコマンド実行関数
シェルとのやり取りのうち、特に日本語等のマルチバイト文字を用いるケースで重宝する
Windows では内部文字コードに cp932 (shift_jis) を使用するソフトに引数を渡す際に使用する"
  (if (string= "windows-nt" (format "%s" system-type))
      (let ((coding-system-for-read 'cp932)
            (coding-system-for-write 'cp932))
        (shell-command-to-string arg))
    (let ((coding-system-for-read 'utf-8)
          (coding-system-for-write 'utf-8))
      (shell-command-to-string arg))))

(defun my-start-process-shell-command (my-process-name my-buffer-name my-command)
  "プロセス開始関数
シェルとのやり取りのうち、特に日本語等のマルチバイト文字を用いるケースで重宝する
Windows では内部文字コードに cp932 (shift_jis) を使用するソフトに引数を渡す際に使用する"
  (if (string= "windows-nt" (format "%s" system-type))
      (let ((coding-system-for-read 'cp932)
            (coding-system-for-write 'cp932))
        (start-process-shell-command my-process-name my-buffer-name my-command))
    (let ((coding-system-for-read 'utf-8)
          (coding-system-for-write 'utf-8))
      (start-process-shell-command my-process-name my-buffer-name my-command))))

(defun my-print (arg eprintf-dir-path)
  "Windows用標準出力関数
出力したい文字列と、eprintf.dll のあるディレクトリのパスを指定する"
  (let ((my-print-filename nil)
        (output-str nil)
        (current-coding-system nil)
        (eprintf-filename nil))
    (with-temp-buffer
      (setq current-coding-system buffer-file-coding-system))
    (setq my-print-filename (expand-file-name (format ".my-print-%s.txt" (eval (cons '+ (current-time)))) eprintf-dir-path))
    (find-file my-print-filename)
    (setq require-final-newline nil)
    (insert arg)
    (let ((coding-system-for-write current-coding-system))
      (save-buffer))
    (goto-char (point-min))
    (while (not (= (point) (point-max)))
      (setq output-str (buffer-substring (point) (progn (end-of-line) (point))))
      (prefer-coding-system 'cp932)
      (set-default 'buffer-file-coding-system 'cp932)
      (setq eprintf-filename (expand-file-name (format ".eprintf-%s.txt" (eval (cons '+ (current-time)))) eprintf-dir-path))
      (find-file eprintf-filename)
      (setq require-final-newline nil)
      (insert output-str)
      (let ((coding-system-for-write 'cp932))
        (save-buffer))
      (kill-buffer (current-buffer))
      (eprintf eprintf-filename)
      (delete-file eprintf-filename)
      (my-del-extra-file eprintf-filename)
      (forward-line 1)
      (unless (and (= (point) (point-max)) (not (= (point) (save-excursion (beginning-of-line) (point)))))
        (princ "\n"))
      (prefer-coding-system current-coding-system)
      (set-default 'buffer-file-coding-system current-coding-system))
    (kill-buffer (current-buffer))
    (delete-file my-print-filename)
    (my-del-extra-file my-print-filename)))

(defun my-msg (arg)
  "日本語出力用関数
半角英数字出力には 'princ' を用いる
前後に1行空行が入る"
  (let (new-arg)
    (with-temp-buffer
      (insert arg)
      (goto-char (point-min))
      (save-excursion
        (while (re-search-forward "%" nil t)
          (replace-match "％")))
           (save-excursion
             (while (re-search-forward "|" nil t)
               (replace-match "｜")))
           (setq new-arg (buffer-substring (point) (progn (end-of-line) (point)))))
    (if (string= "windows-nt" (format "%s" system-type))
        (message (let ((coding-system-for-write 'cp932)
                       (coding-system-for-read 'cp932))
                   (shell-command-to-string (format "echo \"%s\"" new-arg))))
      (message (let ((coding-system-for-write 'utf-8)
                     (coding-system-for-read 'utf-8))
                 (shell-command-to-string (format "echo \"%s\"" new-arg)))))))

(defun my-del-extra-file (filename)
  "ファイル作成時に自動作成される余分なファイルを削除する関数"
  (let ((extra-file-1 nil)
        (extra-file-2 nil))
    (setq extra-file-1 (expand-file-name (format "%s~" (file-name-nondirectory filename)) (file-name-directory filename)))
    (setq extra-file-2 (expand-file-name (format "#%s#" (file-name-nondirectory filename)) (file-name-directory filename)))
    (when (file-exists-p extra-file-1)
      (delete-file extra-file-1))
    (when extra-file-2
      (delete-file extra-file-2))))

(defun my-replace-invalid-filename (string)
  "'string'文字列中に含まれるファイル名に無効な文字を置換して新たな文字列を返す"
  (let (return-str)
    (with-temp-buffer
      (insert string)
      (goto-char (point-min))
      (save-excursion
        (while (search-forward "\\" nil t)
          (replace-match "￥")))
      (save-excursion
        (while (search-forward "/" nil t)
          (replace-match "／")))
      (save-excursion
        (while (search-forward ":" nil t)
          (replace-match "：")))
      (save-excursion
        (while (search-forward "*" nil t)
          (replace-match "＊")))
      (save-excursion
        (while (search-forward "?" nil t)
          (replace-match "？")))
      (save-excursion
        (while (search-forward "\"" nil t)
          (replace-match "”")))
      (save-excursion
        (while (search-forward "<" nil t)
          (replace-match "＜")))
      (save-excursion
        (while (search-forward ">" nil t)
          (replace-match "＞")))
      (save-excursion
        (while (search-forward "|" nil t)
          (replace-match "｜")))
      (setq return-str (buffer-substring (point) (progn (end-of-line) (point)))))))

(defun my-find-new-dirname (dirname)
  "'dirname'ディレクトリが存在すれば、数字付きの新しいディレクトリ名を返す"
  (let ((dirname-number 1)
        new-dirname)
    (if (file-exists-p dirname)
        (progn
          (catch 'find-dirname-end
            (while t
              (if (file-exists-p (format "%s (%s)" dirname dirname-number))
                  (setq dirname-number (1+ dirname-number))
                (setq new-dirname (format "%s (%s)" dirname dirname-number))
                (throw 'find-dirname-end t))))
          new-dirname)
      dirname)))

(defun my-find-new-filename (filename)
  "'filename'ファイルが存在すれば、数字付きの新しいファイル名を返す"
  (let ((filename-number 1)
        (filename-body nil)
        (filename-ext nil)
        (new-filename nil))
    (if (file-exists-p filename)
        (progn
          (catch 'find-filename-end
            (setq filename-body (file-name-sans-extension filename))
            (setq filename-ext (file-name-extension filename))
            (if (string= "nil" filename-ext)
                ;; 拡張子なしの場合
                (while t
                  (if (file-exists-p (format "%s (%s)" filename-body filename-number))
                      (setq filename-number (1+ filename-number))
                    (setq new-filename (format "%s (%s)" filename-body filename-number))
                    (throw 'find-filename-end t)))
              ;; 拡張子ありの場合
              (while t
                (if (file-exists-p (format "%s (%s).%s" filename-body filename-number filename-ext))
                    (setq filename-number (1+ filename-number))
                  (setq new-filename (format "%s (%s).%s" filename-body filename-number filename-ext))
                  (throw 'find-filename-end t)))))
          new-filename)
      filename)))

(defun my-exist-file-part (str)
  "文字列'str'を名前の一部に持つファイルのリストを返し、存在しなければ nil を返す"
  (let ((all-files (directory-files "."))
        (result nil))
    (while all-files
      (with-temp-buffer
        (insert (car all-files))
        (goto-char (point-min))
        (if (search-forward str nil t)
            (setq result (cons (car all-files) result))))
      (setq all-files (cdr all-files)))
    (setq result (reverse result))
    result))

(defun my-exist-file-exc-ext (str)
  "拡張子以外は文字列'str'と名前が共通するファイルのリストを返し、存在しなければ nil を返す"
  (let ((all-files (directory-files "."))
        (filename-exc-ext nil)
        (result nil))
    (while all-files
      (setq filename-exc-ext (file-name-sans-extension (car all-files)))
      (when (string= str filename-exc-ext)
        (setq result (cons (car all-files) result)))
      (setq all-files (cdr all-files)))
    (setq result (reverse result))
    result))

(defun my-count-line (filename)
  "'filename'ファイル中の行数をカウントする"
  (let ((line-counter 0))
    (find-file filename)
    (goto-char (point-min))
    (while (not (= (point) (point-max)))
      (forward-line 1)
      (setq line-counter (1+ line-counter)))
    (kill-buffer filename)
    line-counter))

(defun my-time ()
  "現在日時を返す"
  (format-time-string "%Y/%m/%d(%a) %H:%M:%S" (current-time)))

(defun my-time-add (add-sec)
  "現在日時に'sec'秒加えた日時を返す（うるう年には非対応）"
  (let ((my-year 0)
        (my-month 0)
        (my-date 0)
        (my-day nil)
        (my-hour 0)
        (my-minute 0)
        (my-sec 0)
        (result nil))
    (setq my-year (string-to-number (format-time-string "%Y" (current-time))))
    (setq my-month (string-to-number (format-time-string "%m" (current-time))))
    (setq my-date (string-to-number (format-time-string "%d" (current-time))))
    (setq my-day (format-time-string "%a" (current-time)))
    (setq my-hour (string-to-number (format-time-string "%H" (current-time))))
    (setq my-minute (string-to-number (format-time-string "%M" (current-time))))
    (setq my-sec (+ (string-to-number (format-time-string "%S" (current-time))) add-sec))
    (while (not (and (<= 0 my-sec) (< my-sec 60)))
      (if (<= 60 my-sec)
          (progn
            (setq my-sec (- my-sec 60))
            (setq my-minute (1+ my-minute))
            (if (<= 60 my-minute)
                (progn
                  (setq my-minute (- my-minute 60))
                  (setq my-hour (1+ my-hour))
                  (if (< 23 my-hour)
                      (progn
                        (if (string= "月" my-day)
                            (setq my-day "火")
                          (if (string= "火" my-day)
                              (setq my-day "水")
                            (if (string= "水" my-day)
                                (setq my-day "木")
                              (if (string= "木" my-day)
                                  (setq my-day "金")
                                (if (string= "金" my-day)
                                    (setq my-day "土")
                                  (if (string= "土" my-day)
                                      (setq my-day "日")
                                    (setq my-day "月")))))))
                        (setq my-hour (- my-hour 24))
                        (setq my-date (1+ my-date))
                        (when (or (= 1 my-month) (= 3 my-month) (= 5 my-month) (= 7 my-month) (= 8 my-month) (= 10 my-month) (= 12 my-month))
                          (when (< 31 my-date)
                            (setq my-date (- my-date 31))
                            (setq my-month (1+ my-month))
                            (when (< 12 my-month)
                              (setq my-month (- my-month 12))
                              (setq my-year (1+ my-year)))))
                        (when (or (= 4 my-month) (= 6 my-month) (= 9 my-month) (= 11 my-month))
                          (when (< 30 my-date)
                            (setq my-date (- my-date 30))
                            (setq my-month (1+ my-month))))
                        (when (= 2 my-month)
                          (when (< 28 my-date)
                            (setq my-date (- my-date 28))
                            (setq my-month (1+ my-month)))))))))
        (setq my-sec (+ my-sec 60))
        (setq my-minute (1- my-minute))
        (if (< my-minute 0)
            (progn
              (setq my-minute (+ my-minute 60))
              (setq my-hour (1- my-hour))
              (if (< my-hour 0)
                  (progn
                    (if (string= "日" my-day)
                        (setq my-day "土")
                      (if (string= "土" my-day)
                          (setq my-day "金")
                        (if (string= "金" my-day)
                            (setq my-day "木")
                          (if (string= "木" my-day)
                              (setq my-day "水")
                            (if (string= "水" my-day)
                                (setq my-day "火")
                              (if (string= "火" my-day)
                                  (setq my-day "月")
                                (setq my-day "日")))))))
                    (setq my-hour (+ my-hour 24))
                    (setq my-date (1- my-date))
                    (when (or (= 2 my-month) (= 4 my-month) (= 6 my-month) (= 8 my-month) (= 9 my-month) (= 11 my-month) (= 1 my-month))
                      (when (< my-date 1)
                        (setq my-date (+ my-date 31))
                        (setq my-month (1- my-month))
                        (when (< my-month 1)
                          (setq my-month (+ my-month 12))
                          (setq my-year (1- my-year)))))
                    (when (or (= 5 my-month) (= 7 my-month) (= 8 my-month) (= 12 my-month))
                      (when (< my-date 1)
                        (setq my-date (+ my-date 30))
                        (setq my-month (1- my-month))))
                    (when (= 3 my-month)
                      (when (< my-date 1)
                        (setq my-date (+ my-date 28))
                        (setq my-month (1- my-month))))))))))
    (when (< my-hour 10)
      (setq my-hour (format "0%s" my-hour)))
    (when (< my-minute 10)
      (setq my-minute (format "0%s" my-minute)))
    (when (< my-sec 10)
      (setq my-sec (format "0%s" my-sec)))
    (setq result (format "%s/%s/%s(%s) %s:%s:%s" my-year my-month my-date my-day my-hour my-minute my-sec))
    result))

(defun my-calc-time-taken (start-time end-time)
  "(string-to-number (format-time-string \"%s\" (current-time))) 形式で時間を与えて、かかった時間を '_h _m _s' の形式で返す"
  (let ((taken-sec 0)
        (result nil))
    (setq taken-sec (- end-time start-time))
    (setq result (format "%sh %sm %ss" (/ taken-sec 3600) (/ (% taken-sec 3600) 60) (% taken-sec 60)))
    result))

(defun my-rm-same-atom (list)
  "リストから重なる要素を消して新しいリストを返す"
  (let (list-copy
        new-list)
    (while list
      (setq list-copy (cdr list))
      (catch 'rm-same-atom-end
        (while list-copy
          (if (string= (car list) (car list-copy))
              (throw 'rm-same-atom-end t)
            (setq list-copy (cdr list-copy))))
        (setq new-list (cons (car list) new-list)))
      (setq list (cdr list)))
    (reverse new-list)))

(defun my-exclude-invalid-file (file-list)
  "ファイルリスト'file-list'から '.' と '..' を除外する"
  (let (result)
    (while file-list
      (when (not (or (string= "." (car file-list)) (string= ".." (car file-list))))
        (setq result (cons (car file-list) result)))
      (setq file-list (cdr file-list)))
    (setq result (reverse result))
    result))

(defun my-judge-ext (file ext-list)
  "'file'ファイルの拡張子が拡張子のリスト'ext-list'に含まれる場合は t、そうでない場合は nil を返す"
  (let ((file-ext nil)
        (result nil))
    (setq file-ext (file-name-extension file))
    (catch 'judge-ext-end
      (while ext-list
        (when (string= file-ext (car ext-list))
          (setq result t)
          (throw 'judge-ext-end t))
        (setq ext-list (cdr ext-list)))
      (setq result nil))
    result))

(defun my-find-filename-with-brackets (target-dir ext-list)
  "'target-dir'ディレクトリ中のファイルのうち、名前に '(数字).拡張子(拡張子のリスト'ext-list'に含まれる拡張子)' を持ったファイルのリストを返す"
  (let ((all-files-list nil)
        (ext-list-copy nil)
        (result nil))
    (setq all-files-list (directory-files target-dir))
    (while all-files-list
      (setq ext-list-copy ext-list)
      (with-temp-buffer
        (insert (format "%s" (car all-files-list)))
        (goto-char (point-min))
        (catch 'find-filename-with-brackets-end
          (while ext-list-copy
            (if (re-search-forward (format "([0-9]+)\\.%s$" (car ext-list-copy)) nil t)
                (progn
                  (setq result (cons (car all-files-list) result))
                  (throw 'find-filename-with-brackets-end t)))
            (setq ext-list-copy (cdr ext-list-copy)))))
      (setq all-files-list (cdr all-files-list)))
    (setq result (reverse result))
    result))
;;; my-elisp-util.el ends here
