

# vcwalk

[![GitHub license](<https://img.shields.io/github/license/suyeden/vcwalk?color=blue>)](<https://github.com/suyeden/vcwalk/blob/master/LICENSE>)  


## 概要

Video Converter for Walkman  

手元にある動画を Sony Walkman（旧Sシリーズ・Aシリーズ）向けの動画や音声に変換するための Emacs Lisp スクリプトです。  
厳密には、変換処理自体は FFmpeg に任せており、本スクリプトは FFmpeg のフロントエンドソフトといった立ち位置になります。  


## 動作環境

-   Windows 10 Home
-   GNU Emacs 27.1 以上
-   FFmpeg 4.2.1 以上


## 導入方法

1.  GNU Emacs をダウンロードして適当な場所に展開した上で、Emacs へのパスを通してください。
2.  FFmpeg をダウンロードして適当な場所に展開した上で、FFmpeg へのパスを通してください。
3.  本ページ横の Releases から `vcwalk.zip` をダウンロードし、展開してから中身を適当な場所に配置してください。  
    このとき、中身の `vcwalk.bat` ファイルと `vcwalk` フォルダは必ず同じ場所に置くようにしてください。


## 使用方法

`vcwalk.bat` を実行することで、vcwalk が起動します。  
初めて実行する時は「Windows によって PC が保護されました」というようなメッセージが出てくるかもしれませんが、「詳細情報」を押してから「実行」をクリックすると以降使えるようになります。危険なソフトではないので安心して使ってください。  

`vcwalk.bat` へのパスを通すか、または `vcwalk.bat` のパスを直接指定するなどして、コマンドプロンプトなどのコマンドライン環境から実行してください。  
あるいは、 `vcwalk.bat` をダブルクリックすることでも実行できます。  

起動後は、質問事項にしたがって入力を進めてください。  
変換には動画の個別指定はできず、フォルダ単位で行うため、変換操作対象のフォルダを指定するときにはそのフォルダ内に変換したいファイル以外のファイルは置かないようにしてください。  
デフォルトでは、動画変換では動画ファイルのみを、音声変換では動画ファイルと音声ファイルを変換対象としますが、「動画ファイル以外のファイルも変換しますか？」の質問に何かしらの入力をすることで、テキストファイルとフォルダ以外のすべてのファイルを変換対象に指定することができます。これは、拡張子のないファイルなどを変換したいときに使います。  

「出力先フォルダーのパスを入力」において「vcw-stop」と入力すると、変換操作を行うことなくプログラムを終了させます。  
またその他の質問で「vcw-stop」と入力、あるいは「入力やり直し」の選択肢を選択すると、その時対象にしているフォルダーに対する入力をすべて破棄して、最初の「出力先フォルダーのパスを入力」の質問に戻ります。  
「変換をするつもりで起動したけど、やっぱり今はいいや」などと思った時は、Ctrl-c で中断するのではなく、上記の手順で一度「出力先フォルダーのパスを入力」の項目に戻ってから、さらに「vcw-stop」と入力して本プログラムを終了させてください。  

変換後のファイルの形式などについては以下の作者メモを参照してください。  


## 作者メモ

動画変換時の変換後の動画フォーマット等の設定は以下のようになります。  

<table border="2" cellspacing="0" cellpadding="6" rules="groups" frame="hsides">


<colgroup>
<col  class="org-left" />

<col  class="org-left" />
</colgroup>
<thead>
<tr>
<th scope="col" class="org-left">項目</th>
<th scope="col" class="org-left">設定値</th>
</tr>
</thead>

<tbody>
<tr>
<td class="org-left">動画フォーマット</td>
<td class="org-left">MP4（H.264/MPEG-4 AVC Baseline Profile）</td>
</tr>


<tr>
<td class="org-left">動画サイズ</td>
<td class="org-left">320x240</td>
</tr>


<tr>
<td class="org-left">動画ビットレート</td>
<td class="org-left">384kbps（低画質指定時は256kbps）</td>
</tr>


<tr>
<td class="org-left">動画フレームレート</td>
<td class="org-left">25fps（変換元動画が25fps未満の場合はその値を使用）</td>
</tr>


<tr>
<td class="org-left">音声フォーマット</td>
<td class="org-left">AAC（FFmpeg 内蔵 AAC エンコーダを使用）</td>
</tr>


<tr>
<td class="org-left">音声ビットレート</td>
<td class="org-left">128kbps</td>
</tr>


<tr>
<td class="org-left">音声サンプルレート</td>
<td class="org-left">44100Hz</td>
</tr>
</tbody>
</table>

音声変換時の変換後の音声フォーマット等の設定は以下のようになります。  

<table border="2" cellspacing="0" cellpadding="6" rules="groups" frame="hsides">


<colgroup>
<col  class="org-left" />

<col  class="org-left" />
</colgroup>
<thead>
<tr>
<th scope="col" class="org-left">項目</th>
<th scope="col" class="org-left">設定値</th>
</tr>
</thead>

<tbody>
<tr>
<td class="org-left">音声フォーマット</td>
<td class="org-left">MP3（libmp3lame を使用）</td>
</tr>


<tr>
<td class="org-left">音声ビットレート</td>
<td class="org-left">128kbps</td>
</tr>


<tr>
<td class="org-left">音声サンプルレート</td>
<td class="org-left">44100Hz</td>
</tr>
</tbody>
</table>

なお変換の際、対応する Nvidia の GPU が PC に搭載されている場合には自動的に NVENC を用いたハードウェアエンコードを行うようにしています。  

