#!/bin/bash

rom_fp="$(date +%y%m%d)"
originFolder="$(dirname "$0")"
mkdir -p release/$rom_fp/
set -e

if [ -z "$USER" ];then
	export USER="$(id -un)"
fi
export LC_ALL=C

manifest_url="https://android.googlesource.com/platform/manifest"
aosp="android-8.1.0_r65"
phh="android-8.1"

if [ "$1" == "android-9.0" ];then
    manifest_url="https://github.com/CesiumOS-org/manifest"
    aosp="eleven"
    phh="eleven"
elif [ "$1" == "android-10.0" ];then
    manifest_url="https://github.com/CesiumOS-org/manifest"
    aosp="eleven"
    phh="eleven"
elif [ "$1" == "android-11.0" ];then
    manifest_url="https://github.com/CesiumOS-org/manifest"
    aosp="eleven"
    phh="android-11.0"
fi

if [ "$release" == true ];then
    [ -z "$version" ] && exit 1
    [ ! -f "$originFolder/release/config.ini" ] && exit 1
fi

repo init -u "$manifest_url" -b $aosp
if [ -d .repo/local_manifests ] ;then
	( cd .repo/local_manifests; git fetch; git reset --hard; git checkout origin/$phh)
else
	git clone https://github.com/phhusson/treble_manifest .repo/local_manifests -b $phh
fi
repo sync -c -j 1 --force-sync

repo forall -r '.*opengapps.*' -c 'git lfs fetch && git lfs checkout'
(cd device/phh/treble; git clean -fdx; bash generate.sh)
(cd vendor/foss; git clean -fdx; bash update.sh)
rm -f vendor/gapps/interfaces/wifi_ext/Android.bp

. build/envsetup.sh


repo manifest -r > release/$rom_fp/manifest.xml
bash "$originFolder"/list-patches.sh
cp patches.zip release/$rom_fp/patches.zip

if [ "$1" = "android-11.0" ];then
    (
        git clone https://github.com/phhusson/sas-creator
        cd sas-creator

        git clone https://github.com/phhusson/vendor_vndk -b android-10.0
    )


    lunch cesium_CPH1859-userdebug
    make bacon -j8
elif [ "$1" = "android-10.0" ];then
        lunch cesium_CPH1859-userdebug
        make bacon -j8
else

	rm -Rf out/target/product/phhgsi*

	if [ "$1" = "android-9.0" ];then
        lunch cesium_CPH1859-userdebug
        make bacon -j8
	buildVariant treble_a64_bgS-userdebug arm32_binder64-ab-gapps-su
	fi
	rm -Rf out/target/product/phhgsi*
fi

if [ "$release" == true ];then
    (
        rm -Rf venv
        pip install virtualenv
        export PATH=$PATH:~/.local/bin/
        virtualenv -p /usr/bin/python3 venv
        source venv/bin/activate
        pip install -r $originFolder/release/requirements.txt

        name="AOSP 8.1"
        [ "$1" == "android-9.0" ] && name="AOSP 9.0"
        python $originFolder/release/push.py "$name" "$version" release/$rom_fp/
        rm -Rf venv
    )
fi
