# ----------------------------------------------------------
# [Requirements]
#   - Adobe AIR 3.9 SDK
#   - Adobe Flex 4.6 SDK
# ----------------------------------------------------------

# List up this Makefile's targets.
list:
	grep "^[^#].*:$$" Makefile

run:
	ln -s -f ../asset/asset ./build/
	adl projects/debug-project/src/DebugMain-app.xml build/ -screensize 640x960:640x960

# [Required] colorline command:
#     https://github.com/tatsuya-koyama/MyScript/blob/master/colorline
run2:
	ln -s -f ../../asset/asset ./build/
	make run 2>&1 | colorline Error Warning AssetManager LayerManager FSM processCount

debug:
	mxmlc -incremental=true \
	      -library-path+="lib/" \
	      -library-path+="../lib/" \
	      -library-path+="../lib-ex/" \
	      -source-path+="core-src/" \
	      -source-path+="lib-src/" \
	      -source-path+="../krew-framework/" \
	      -swf-version=25 \
	      -output="build/DebugMain.swf" \
	      -debug=true \
	      projects/debug-project/src/DebugMain.as

debug_run:
	make debug
	make run

debug_run2:
	make debug
	make run2

# web での公開用
flash:
	mxmlc -incremental=true \
	      -library-path+="lib/" \
	      -library-path+="../lib/" \
	      -library-path+="../lib-ex/" \
	      -source-path+="core-src/" \
	      -source-path+="lib-src/" \
	      -source-path+="../krew-framework/" \
	      -swf-version=25 \
	      -output="build/krewdemo.swf" \
	      -debug=false \
	      projects/web-project/src/WebMain.as

# [Note]
# ASC2.0 では -incremental オプションは無くなったが、コマンドラインビルドでは
# FlashBuilder がやっている「2 回目以降のビルド時間を短縮する機構」が働かないため、
# コマンドラインでは当面、旧式のコンパイラを使用している


# AIR for Android のもとになる swf をつくる
air-android:
	rm -f build/krewdemo-AIR.swf
	amxmlc -library-path+="lib/" \
	       -library-path+="../lib/" \
	       -library-path+="../lib-ex/" \
	       -source-path+="core-src/" \
	       -source-path+="lib-src/" \
	       -source-path+="../krew-framework/" \
	       -swf-version=25 \
	       -output="build/AndroidMain.swf" \
	       -debug=false \
	       projects/android-project/src/AndroidMain.as

# パッケージングするための証明書の作成
cert:
	adt -certificate -validityPeriod 25 -cn SelfSigned 1024-RSA build/krewSampleCert.p12 krewsamplepassword

# Android 用の apk を作成。
# make air-android 実行後にやること
# (make cert も一度実行しておく必要がある)
android:
	cd build/; \
	adt -package -target apk-captive-runtime \
	    -storetype pkcs12 \
	    -keystore krewSampleCert.p12 \
	    -storepass krewsamplepassword \
	    krewdemo.apk \
	    ../projects/android-project/src/AndroidMain-app.xml \
	    AndroidMain.swf \
	    -C ../asset asset

# USB 接続状態の実機にビルドした apk をインストールする。
# make install-android 実行後にやること。
# adb はパスが通っている必要がある
install-android:
	adb install -r build/krewdemo.apk


# Using Ruby script from Sparrow framework
#     http://gamua.com/sparrow/
#
# [Required]
# $ gem install quick_magick
#
# [Usage]
# 1. Put png files to /asset/image_src/{ATLAS_NAME}/
# 2. Make it:
#
#       $ make atlas p={ATLAS_NAME}
#
#    then atlas_{ATLAS_NAME}.png and atlas_{ATLAS_NAME}.xml
#    are generated into /asset/image/.
#
atlas:
	../sample-game/script/atlas_generator/generate_atlas.rb --padding 2 --maxsize 1024x1024 \
	asset/workfile/image_src/$(p)/*.png asset/asset/image/atlas_$(p).xml

clean:
	rm -f build/*.swf
	rm -f build/*.swf.cache
	rm -f build/*.apk
	rm -f build/*.ipa
	rm -rf build/*.tmp

