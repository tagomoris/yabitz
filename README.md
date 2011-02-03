# Yabitz

* yabitz - Yet Another Business Information Tracker Z
* http://github.com/tagomoris/yabitz

* by tagomoris (tagomrois at gmail.com, tagomoris at livedoor.jp, @tagomoris on Twitter)

## DESCRIPTION

'yabitz'(ヤビツ) は、ユーザ(多くの場合は企業)が保有するホスト、IPアドレス、データセンタラック、サーバハードウェア、OSなどの情報を管理するためのWebアプリケーションです。

どのようなホストがどこに何台あり、どのように変わってきたのかという情報は1000台規模になると把握が極めて困難となります。また互いに矛盾する情報であっても、簡単なスプレッドシートなどでは気付くことすら不可能であったりします。そのような状況に対処するために開発されています。
また任意のホストに対して任意のタグをつけることが可能なため、アプリケーションの自動デプロイ対象の特定など、他システムとの連携を志向してAPI等が準備されています。

だいたいにおいて数千台規模のホスト管理に使用するために作られています。厳密な意味での構成管理や性能監視などの機能は備えていません。情報の集約とチェックにのみ特化したものです。(ライブドアでは2011年2月現在で約3800ホストの情報が登録され、使用されています。)

主に以下のような機能を備えています。

* 部署/コンテンツ/サービス という階層によるホストの登録と分類
* ホストに対する以下の情報の登録
 * 状態 (稼働中、準備中、撤去依頼済み、撤去済み、……)
 * dns name
 * ハードウェアID
 * ラック位置
 * ハードウェア種別
 * メモリ、ディスク容量
 * OS種別
 * Local IPアドレス、Global IPアドレス、Virtual IPアドレス
 * タグ、メモ
 * 仮想マシンに対するハイパーバイザへの関連付け
 * 障害時の連絡先情報
* 各種情報をキーにしたホスト検索と一覧表示
 * およびそれらのデータの json/csv 出力
* ホスト情報への変更の追跡や差分表示
 * 特定ホストに対して、ある期間に行われた変更内容の一覧や差分表示
 * サービス単位でのある期間に行われた変更の差分表示
* IPセグメントやラック単位での使用状況の確認
* ハードウェア種類別やOS別のホスト数の確認
* 各コンテンツ/サービスやステータスごとの利用状況サマリの計算
 * ホスト数、使用ユニット数 など
* 情報の欠損や矛盾する登録情報のチェック
* プラグインによる拡張
 * 認証システムの社内システムへの連携 (ActiveDirectory/LDAPなど)
 * 特有のラック形式の登録と表示
 * 各ホスト情報からの社内の他システムへのリンクの追加
 * 独自形式のタグの追加
* Web API経由でのホスト情報の更新

動作環境は以下の通りです。
* サーバ環境
 * Ruby 1.9.2 (1.9.1以前および1.8系では動作しません)
  * sinatra, haml/sass, ruby-ldap, ruby-mysql, rspec
  * Stratum (see https://github.com/tagomoris/Stratum )
 * MySQL 5.1.x (5.0や5.5でも動作はすると思いますが、未確認です)
 * 適当な Linux もしくは Mac OS X (Windowsでは動作しません)
* クライアント環境
 * モダンなブラウザ (Chrome, Safari, Firefox ...)
 * IEでの閲覧はデザインが大変崩れます (動作はする。はず。)

## Status

絶賛開発中です。ライブドアではこのリポジトリのコードをそのまま使用して、実装・改良しながら運用しています。
情報の種類によっては、登録はできるけど削除ができなかったりします。そのうちできるようになると思います。

ユーザインターフェイスの見た目がいまいち残念なのは今のところどうにかなる予定はありません。

## HOW TO RUN
### 言語、ミドルウェア、ライブラリ

適当なLinuxサーバで以下のものをインストールします。
* Ruby 1.9.2
* MySQL 5.1.x (or 5.5 ?)
MySQLにおける認証設定は適宜行ってください。

また以下のRuby Gemsをインストールします。(全て最新のもので良いはず)
* sinatra
* haml
* ruby-ldap
* ruby-mysql
* rspec

SinatraのアプリケーションサーバとしてPhusion Passengerを使用する場合は Apache2 および passenger をインストールします。

また依存ライブラリである Stratum を適当な場所に git clone します。

    $ cd /path/to/your/lib
    $ git clone git://github.com/tagomoris/Stratum.git

### yabitzの展開と設定

適当な場所に yabitz を git clone します。

    $ cd /path/to/your/app
    $ git clone git://github.com/tagomoris/yabitz.git

yabitz の動作設定を config プラグインとして作成します。とりあえず試す範囲であれば、デフォルトで用意されているものがあります。

    $ cd yabitz
    $ cat lib/yabitz/plugin/config_instant.rb
    # -*- coding: utf-8 -*-
    
    module Yabitz::Plugin
      module InstantConfig
        def self.plugin_type
          :config
        end
        def self.plugin_priority
          1
        end
    
        def self.extra_load_path(env)
          if env == :production
            ['~/Documents/Stratum']
          else
            ['~/Documents/Stratum']
          end
        end
    
        DB_PARAMS = [:server, :user, :pass, :name, :port, :sock]
    
        CONFIG_SET = {
          :database => {
            :server => 'localhost',
            :user => 'root',
            :pass => nil,
            :name => 'yabitz_instant',
            :port => nil,
            :sock => nil,
          },
          :test_database => {
            :server => 'localhost',
            :user => 'root',
            :pass => nil,
            :name => 'yabitztest',
            :port => nil,
            :sock => nil,
          },
        }
    
        def self.dbparams(env)
          if env == :test
            DB_PARAMS.map{|sym| CONFIG_SET[:test_database][sym]}
          else
            DB_PARAMS.map{|sym| CONFIG_SET[:database][sym]}
          end
        end
      end
    end
  
最低限、以下の点を確認・修正してください。

* ライブラリのロードバス指定 (extra_load_path)
 * Stratumを展開したディレクトリは必ずここで指定してください
  * 独自にプラグインを追加する場合には、プラグインが依存する(Ruby管理外の)ライブラリのパスはここで追加する必要があります
* データベース接続設定
 * 動作させるだけであれば :database 内の server/user/pass/name を指定してください
 * ここで指定するユーザには、指定するデータベース名に対するCREATE/DROP権限をMySQL側でつけておく必要があります
 
上記設定が正常になっていれば、以下のコマンドでデータベースおよびテーブルが作成されます。

    $ RACK_ENV=production ruby scripts/db_schema.rb

また yabitz は情報の登録や編集、および連絡先情報の閲覧には必ず認証を要求します。認証情報は以下の方法から参照することができます。

* 添付の instant_membersource プラグインを使用する
 * lib/yabitz/plugin/instant_membersource.rb
 * プラグイン内で指定するデータベースに認証情報マスタとなるテーブルを作成し、参照します
 * 全ユーザ情報をあらかじめこのテーブルに登録する必要があります
  * いちおう登録・編集用のコマンドラインインターフェイスを提供するスクリプトを同梱してありますが、機能は貧弱です
* 任意のファイルや外部システムを参照するプラグインを追加する
 * ライブドア社内ではActiveDirectoryを参照して認証情報を確認するためのプラグインを作成・使用しています
 * いちおう auth_dummy プラグイン(認証情報の参照/LDAP) および member_dummy プラグイン(社員名簿マスタの参照/CSV) を例として用意してあります

とりあえず起動させるだけの場合は instant_membersource を使用することにして、以下のコマンドを実行します。

    $ vi scripts/instant/db_schema_membersource.rb # データベース名およびテーブル名を編集(問題なければデフォルトのままで)
    $ vi lib/yabitz/plugin/instant_membersource.rb # データベースのホスト名、ユーザ名とパスワード、データベース名およびテーブル名を編集
    $ ruby scripts/instant/db_schema_membersource.rb

上記コマンド実行後、最低限のユーザ登録を済ませます(データベース名やテーブル名を変更した場合は実行前にこのスクリプトの記述も修正すること。)。データベースへの接続にパスワードが必要な場合は最後に -p を指定すると、プロンプトで確認されます。

    $ ruby scripts/instant/register_user.rb HOSTNAME USERNAME [-p]

このスクリプトを実行すると、以下の情報の入力を求められます。
* ユーザ名
* パスワード
* メールアドレス (省略可)
* 社員番号 (省略可)
* 役職 (省略可)

氏名や役職には日本語が使用できます。また既に登録済みのユーザ名を入力した場合は登録内容の変更を実施します。
これらの登録情報は yabitz における認証や連絡先情報の検索ソースとして使用されます。(yabitz起動中にこれらのスクリプトを実行しても問題ありません。)

上記準備が完了したら yabitz を起動します。sinatraには組込みサーバがあるため、以下のコマンドで localhost:8180 で起動します。

    $ RACK_ENV=production ruby lib/yabitz/app.rb

また mod_passenger で起動したい場合には以下のようにApacheの設定に追加します。(モジュールやRubyのパスは自分の環境にあわせて適当に。)

    LoadModule passenger_module /usr/local/lib/ruby/gems/1.9.1/gems/passenger-3.0.0/ext/apache2/mod_passenger.so
    PassengerRoot /usr/local/lib/ruby/gems/1.9.1/gems/passenger-3.0.0
    PassengerRuby /usr/local/bin/ruby
    PassengerDefaultUser root
    
    <VirtualHost *>
      ServerName yabitz.example.com
    
      DocumentRoot /path/to/your/app/yabitz/public
      RackEnv production
    
      <Directory /path/to/your/app/yabitz/public>
        Options +FollowSymLinks
        AllowOverride None
        
        Order Deny,Allow
        Deny from All
        Allow from 10.0.0.0 # your local network
      </Directory>
    
      <Location />
        Order Deny,Allow
        Deny from All
        Allow from 10.0.0.0 # your local network
      </Location>
    </VirtualHost>

これらの設定を有効にした上で /ybz にアクセスすればトップページが出てきます。

## WHAT YOU MUST DO

yabitz ではホスト情報の登録・編集などは原則として「ADMIN」の権限を持っているユーザのみが行えます。(例外として、ADMIN権限が誰にも設定されていない場合に限り、ログインした人は誰でもADMIN権限を保持しているものとして処理されます。またホスト情報のメモやタグ、連絡先情報などは一般権限のユーザでも編集が可能です。)

各ユーザの権限は、画面右上部メニューの「管理項目」から「ユーザリスト」を参照すると確認できます。各行をクリックすると表示される詳細ボックスにおいて、権限や状態のトグルが行えます。このユーザデータは、一度でもログインに成功したユーザ名について自動的に作成されます。

yabitz でホスト管理を行うには、最低限以下の情報を登録する必要があります。

* 部署名のリスト
 * 使用ホスト/ユニット数をカウントする際の最も大きい集計単位
 * ログイン後、メニューの「各種リスト」から「部署」を開いて入力欄から追加
* コンテンツのリスト
 * 使用ホスト/ユニット数をカウントする際の基本的な単位
  * 集計に必要なコードを登録できる
 * 部署追加後、メニューの「各種リスト」から「コンテンツ」を開いて入力欄から追加
* サービスのリスト
 * ホストをまとめる基本的な単位
  * 障害時連絡先などはサービスを単位に設定
 * コンテンツ追加後、メニューの「サービス一覧」を開いて入力欄から追加
* HW情報のリスト
 * ハードウェア筐体名ごとにサイズ、計算時の論理サイズ(ハーフ筐体などに対応)を保持
 * メニューの「各種リスト」から「HW情報」を開いて入力欄から追加
* OS情報のリスト
 * ホスト登録時に選択できるOS名のリスト
 * メニューの「各種リスト」から「OS情報」を開いて入力欄から追加

また他に「Local NW」「Global NW」を登録しておけば、各ネットワークセグメントの使用状況などが確認できるようになります。

ホスト自体の登録は、ログイン後に「管理項目」の「ホスト登録」から行います。

## HOW TO WRITE/USE PLUGIN

データセンタ事業者ごとにラックのサイズなどは異なりますし、またラック/ラック内位置の名付け規則なども異なるものと思います。標準では42Uのラックのみ対応プラグインが同梱されています。

また認証の連携や社員マスタの参照、ホスト表示時の社内連携システムへのリンク追加など、プラグインを追加することで可能なことはそれなりに色々あります。すべてについてドキュメントは現状では書けません(また yabitz 内部仕様への理解がそれなりに必要になってしまいます)。
何か追加の必要がありそうな場合は lib/yabitz/plugin.rb を読んでみてください。また lib/yabitz/plugin ディレクトリに各種のダミープラグインがありますので、そちらも参考にしてみてください。わからない点については遠慮なく作者までご連絡ください。

## FAQ
* ヤビツってなに
 * http://ja.wikipedia.org/wiki/%E3%83%A4%E3%83%93%E3%83%84%E5%B3%A0
* Z ってなに
 * ドラゴンボールZのZみたいなもの

* * * * *

## License

Copyright 2011 TAGOMORI Satoshi (tagomoris)

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

   http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
