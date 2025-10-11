{
  zigHook,
  zigBin,
  zigSrc,
  fetchFromMirror,
  llvmPackages_21,
  llvmPackages_20,
  llvmPackages_19,
  llvmPackages_18,
}:

let
  bin = release: zigBin { inherit zigHook release fetchRelease; };
  src =
    release: llvmPackages:
    zigSrc {
      inherit
        zigHook
        release
        fetchRelease
        llvmPackages
        ;
    };

  fetchRelease = fetchFromMirror {
    zigMirrors = ''
      https://pkg.machengine.org/zig
      https://zigmirror.hryx.net/zig
      https://zig.linus.dev/zig
      https://zig.squirl.dev
      https://zig.florent.dev
      https://zig.mirror.mschae23.de/zig
      https://zigmirror.meox.dev
    '';
  };

  meta-master = {
    version = "0.16.0-dev.699+529aa9f27";
    date = "2025-10-09";
    docs = "https://ziglang.org/documentation/master/";
    stdDocs = "https://ziglang.org/documentation/master/std/";

    src = {
      filename = "zig-0.16.0-dev.699+529aa9f27.tar.xz";
      shasum = "679b0f89afc273ebab3d6dd9a2d78bbbe98ce471f105e745ea56dbc731d1e48b";
      size = 21452592;
    };

    bootstrap = {
      filename = "zig-bootstrap-0.16.0-dev.699+529aa9f27.tar.xz";
      shasum = "e87b6190cc13d3546566add207329b369ad4a2e304a6c0c810744246c12a2bb6";
      size = 54211052;
    };

    x86_64-darwin = {
      filename = "zig-x86_64-macos-0.16.0-dev.699+529aa9f27.tar.xz";
      shasum = "b8df0105b5ca3cb661d9870f33e0cffbc3c0351031711b3fda19486cbaf3b0fc";
      size = 56562800;
    };

    arm64-darwin = {
      filename = "zig-aarch64-macos-0.16.0-dev.699+529aa9f27.tar.xz";
      shasum = "9b1f6e27e14e83370d77d3effdce1199d89e854ca210e13822a8dd77e3146301";
      size = 51409748;
    };

    x86_64-linux = {
      filename = "zig-x86_64-linux-0.16.0-dev.699+529aa9f27.tar.xz";
      shasum = "ac7d326c488b7cf60dfb79a929abf8aa26851f3408854f0f3f996ddaab04fe13";
      size = 54487484;
    };

    aarch64-linux = {
      filename = "zig-aarch64-linux-0.16.0-dev.699+529aa9f27.tar.xz";
      shasum = "198010cdf7a2c424f601060e8664a0bccef3f6514fb0810fe009ca5e5a214394";
      size = 50245624;
    };

    armv7l-linux = {
      filename = "zig-arm-linux-0.16.0-dev.699+529aa9f27.tar.xz";
      shasum = "f4a70827ae0026f1768f92c2bcf27c8a6535f036de4694388a3d930417b609f1";
      size = 51083556;
    };

    riscv64-linux = {
      filename = "zig-riscv64-linux-0.16.0-dev.699+529aa9f27.tar.xz";
      shasum = "925071458b37dbb112edabdb3d4e0cc31fc632bd414db579824fa7e4307daa39";
      size = 54270020;
    };

    powerpc64le-linux = {
      filename = "zig-powerpc64le-linux-0.16.0-dev.699+529aa9f27.tar.xz";
      shasum = "1d3b95f63c6baf56a4defe2af4d74b8776e07e6a0e9b7bcc05a30bd8c7044169";
      size = 54291688;
    };

    i686-linux = {
      filename = "zig-x86-linux-0.16.0-dev.699+529aa9f27.tar.xz";
      shasum = "9ed94c9c3fc2932d4ba81b8b52de2f7d170c6a9ba2fccdf5fec247873d3dbce8";
      size = 57151124;
    };

    loongarch64-linux = {
      filename = "zig-loongarch64-linux-0.16.0-dev.699+529aa9f27.tar.xz";
      shasum = "2de608947717bde455d781a0a6d977bee3fb37bfa606beef6ddccd1acfa3efcb";
      size = 51524348;
    };

    s390x-linux = {
      filename = "zig-s390x-linux-0.16.0-dev.699+529aa9f27.tar.xz";
      shasum = "3f9b2dae3cbd39b969a7e39d95daa744ea2def450bdc342ea9b0f43551bce234";
      size = 53976276;
    };

    x86_64-mingw32 = {
      filename = "zig-x86_64-windows-0.16.0-dev.699+529aa9f27.zip";
      shasum = "259ed42a77523ca3c9ca6cd412cff315dd2704f7053aca23240447488069e7b6";
      size = 94261862;
    };

    aarch64-mingw32 = {
      filename = "zig-aarch64-windows-0.16.0-dev.699+529aa9f27.zip";
      shasum = "d348364c6a606016fb96fbbe46e95ec05f0e8ba466d0e859cd74425da49bb792";
      size = 90212432;
    };

    i686-mingw32 = {
      filename = "zig-x86-windows-0.16.0-dev.699+529aa9f27.zip";
      shasum = "82a9bdd704bae9d183b27e0e00386c0db0b5ca10da0f435919e9357a7c050a83";
      size = 96071680;
    };

    aarch64-freebsd = {
      filename = "zig-aarch64-freebsd-0.16.0-dev.699+529aa9f27.tar.xz";
      shasum = "8ae84c9b5334baae2f65e807232fd3689e3c794629b2347358f402035ddf359e";
      size = 50171640;
    };

    armv7l-freebsd = {
      filename = "zig-arm-freebsd-0.16.0-dev.699+529aa9f27.tar.xz";
      shasum = "06294c5082524c6050a1e39930a800475a48c7e92ec24e947374ea400880923c";
      size = 51759640;
    };

    powerpc64-freebsd = {
      filename = "zig-powerpc64-freebsd-0.16.0-dev.699+529aa9f27.tar.xz";
      shasum = "d408a4987da34a9e945b75012ee0bb2563ddbd278b128b13471fe55d62eb9706";
      size = 52850036;
    };

    powerpc64le-freebsd = {
      filename = "zig-powerpc64le-freebsd-0.16.0-dev.699+529aa9f27.tar.xz";
      shasum = "7947218322d722327165ab0f4be7b0d758482ba3bd210b8d6bf948a5c25348b8";
      size = 54297776;
    };

    riscv64-freebsd = {
      filename = "zig-riscv64-freebsd-0.16.0-dev.699+529aa9f27.tar.xz";
      shasum = "1a8f064add05f4902fe813e4ea72ce79fb12f33220bb195b43d7a9240e7b7823";
      size = 54400448;
    };

    x86_64-freebsd = {
      filename = "zig-x86_64-freebsd-0.16.0-dev.699+529aa9f27.tar.xz";
      shasum = "89b457df678f1a96fe5c41570a07e039b8ee5fa4dd21df3a90e58572510993f2";
      size = 54612160;
    };

    aarch64-netbsd = {
      filename = "zig-aarch64-netbsd-0.16.0-dev.699+529aa9f27.tar.xz";
      shasum = "a76eedf43c75117d40b792f93a5ca8e412cc435736f5751879c75383e2faeef0";
      size = 50130612;
    };

    armv7l-netbsd = {
      filename = "zig-arm-netbsd-0.16.0-dev.699+529aa9f27.tar.xz";
      shasum = "1b6842f925ed9459a90288ae8ce4277a6ffb5acdec78cea86bd11af2d03a3fd6";
      size = 52794584;
    };

    i686-netbsd = {
      filename = "zig-x86-netbsd-0.16.0-dev.699+529aa9f27.tar.xz";
      shasum = "dd87bf55bfcb0564add88ddfb1161dce83d8cd05cbed5690f6dd9c1f130efb83";
      size = 57762868;
    };

    x86_64-netbsd = {
      filename = "zig-x86_64-netbsd-0.16.0-dev.699+529aa9f27.tar.xz";
      shasum = "b73bfb14498c2f24a3d110d8398a6172c489daf86be3c577cf5fb2d6b802fde6";
      size = 54539744;
    };
  };

  meta-0_15_1 = {
    version = "0.15.1";
    date = "2025-08-19";
    docs = "https://ziglang.org/documentation/0.15.1/";
    stdDocs = "https://ziglang.org/documentation/0.15.1/std/";
    notes = "https://ziglang.org/download/0.15.1/release-notes.html";

    src = {
      filename = "zig-0.15.1.tar.xz";
      shasum = "816c0303ab313f59766ce2097658c9fff7fafd1504f61f80f9507cd11652865f";
      size = 21359884;
    };

    bootstrap = {
      filename = "zig-bootstrap-0.15.1.tar.xz";
      shasum = "4c0cfbcf12da144955761ca43f89e3c74956bce978694fc1d0a63555f5c0a199";
      size = 52711548;
    };

    x86_64-darwin = {
      filename = "zig-x86_64-macos-0.15.1.tar.xz";
      shasum = "9919392e0287cccc106dfbcbb46c7c1c3fa05d919567bb58d7eb16bca4116184";
      size = 55791880;
    };

    arm64-darwin = {
      filename = "zig-aarch64-macos-0.15.1.tar.xz";
      shasum = "c4bd624d901c1268f2deb9d8eb2d86a2f8b97bafa3f118025344242da2c54d7b";
      size = 50644996;
    };

    x86_64-linux = {
      filename = "zig-x86_64-linux-0.15.1.tar.xz";
      shasum = "c61c5da6edeea14ca51ecd5e4520c6f4189ef5250383db33d01848293bfafe05";
      size = 53734456;
    };

    aarch64-linux = {
      filename = "zig-aarch64-linux-0.15.1.tar.xz";
      shasum = "bb4a8d2ad735e7fba764c497ddf4243cb129fece4148da3222a7046d3f1f19fe";
      size = 49493872;
    };

    armv7l-linux = {
      filename = "zig-arm-linux-0.15.1.tar.xz";
      shasum = "3f4bf3b06b67d14e3f38be30798488c1abe3cf5b33de570cd0e87bbf09b978ad";
      size = 50477464;
    };

    riscv64-linux = {
      filename = "zig-riscv64-linux-0.15.1.tar.xz";
      shasum = "7ca7a3e621436fb31d66a253132fc39574a13d2a1b4d8458af4f2e7c6e4374fe";
      size = 53597792;
    };

    powerpc64le-linux = {
      filename = "zig-powerpc64le-linux-0.15.1.tar.xz";
      shasum = "339e2106496be70b614e32d444298216e676c36d08f5cd7bee3dd1dbd4567fd7";
      size = 53566944;
    };

    i686-linux = {
      filename = "zig-x86-linux-0.15.1.tar.xz";
      shasum = "dff166f25fdd06e8341d831a71211b5ba7411463a6b264bdefa8868438690b6a";
      size = 56311228;
    };

    loongarch64-linux = {
      filename = "zig-loongarch64-linux-0.15.1.tar.xz";
      shasum = "0af18a012f3c4cffbef29ab5f42021484d92517f921a1380faacc89c50c1f89d";
      size = 50794376;
    };

    s390x-linux = {
      filename = "zig-s390x-linux-0.15.1.tar.xz";
      shasum = "bcd13e5c88cf2d0da7100a48572195560069a94402c9bec3b316398204aa27e2";
      size = 53508068;
    };

    x86_64-mingw32 = {
      filename = "zig-x86_64-windows-0.15.1.zip";
      shasum = "91e69e887ca8c943ce9a515df3af013d95a66a190a3df3f89221277ebad29e34";
      size = 92612958;
    };

    aarch64-mingw32 = {
      filename = "zig-aarch64-windows-0.15.1.zip";
      shasum = "1f1bf16228b0ffcc882b713dc5e11a6db4219cb30997e13c72e8e723c2104ec6";
      size = 88458549;
    };

    i686-mingw32 = {
      filename = "zig-x86-windows-0.15.1.zip";
      shasum = "fb1c07cffbb43615d3158ab8b8f5db5da1d48875eca99e1d7a8a0064ff63fc5b";
      size = 94516052;
    };

    aarch64-freebsd = {
      filename = "zig-aarch64-freebsd-0.15.1.tar.xz";
      shasum = "4d9d25c775828d49ea037b2284310c295d951793da8ebe94827a54fed4cca3ce";
      size = 49358464;
    };

    armv7l-freebsd = {
      filename = "zig-arm-freebsd-0.15.1.tar.xz";
      shasum = "9707f3a5f7e1a3d99c40db9a74de1acc61016a197ad289c2ad964f93cb213a18";
      size = 50904124;
    };

    powerpc64-freebsd = {
      filename = "zig-powerpc64-freebsd-0.15.1.tar.xz";
      shasum = "79448884372db04e62f77a46b92245fce805063e69534729537f75cb4681e7e3";
      size = 52099020;
    };

    powerpc64le-freebsd = {
      filename = "zig-powerpc64le-freebsd-0.15.1.tar.xz";
      shasum = "f18ee12ba9c98a20b8d2ad0410c679e7aa5591bc7917f169fd6b377833d2c7ad";
      size = 53480976;
    };

    riscv64-freebsd = {
      filename = "zig-riscv64-freebsd-0.15.1.tar.xz";
      shasum = "ee9f864a6fd8b57c1f4fdbb11daa06578746a6f8253afe3f5ddb5a76f2eddd2d";
      size = 53677800;
    };

    x86_64-freebsd = {
      filename = "zig-x86_64-freebsd-0.15.1.tar.xz";
      shasum = "9714f8ac3d3dc908b1599837c6167f857c1efaa930f0cfa840699458de7c3cd0";
      size = 53782112;
    };

    aarch64-netbsd = {
      filename = "zig-aarch64-netbsd-0.15.1.tar.xz";
      shasum = "b2a528399777583b85b89c54ccd45488af7709d6dd29a27323ec2a229db40910";
      size = 49368000;
    };

    armv7l-netbsd = {
      filename = "zig-arm-netbsd-0.15.1.tar.xz";
      shasum = "93dc70109cbf5d2e022d20dfb56211978c4ea3c0b1e67aaabff947d8d1583aab";
      size = 52028184;
    };

    i686-netbsd = {
      filename = "zig-x86-netbsd-0.15.1.tar.xz";
      shasum = "a91b26051822ff17f3143f859b87dce5b4a13e90928bd6daa6f07a895d3410f0";
      size = 56881864;
    };

    x86_64-netbsd = {
      filename = "zig-x86_64-netbsd-0.15.1.tar.xz";
      shasum = "6d7ba6eca5b4434351ebdb971b7303c9934514f9bb8481852251dbd5b52b03d6";
      size = 53794836;
    };
  };

  meta-0_14_1 = {
    version = "0.14.1";
    date = "2025-05-21";
    docs = "https://ziglang.org/documentation/0.14.1/";
    stdDocs = "https://ziglang.org/documentation/0.14.1/std/";

    src = {
      filename = "zig-0.14.1.tar.xz";
      shasum = "237f8abcc8c3fd68c70c66cdbf63dce4fb5ad4a2e6225ac925e3d5b4c388f203";
      size = 17787696;
    };

    bootstrap = {
      filename = "zig-bootstrap-0.14.1.tar.xz";
      shasum = "89b2fce50bfbb1eee29c382193d22c6eb0c7da3a96b5ba6d05e0af2945b3ca3d";
      size = 48041028;
    };

    x86_64-darwin = {
      filename = "zig-x86_64-macos-0.14.1.tar.xz";
      shasum = "b0f8bdfb9035783db58dd6c19d7dea89892acc3814421853e5752fe4573e5f43";
      size = 51044512;
    };

    arm64-darwin = {
      filename = "zig-aarch64-macos-0.14.1.tar.xz";
      shasum = "39f3dc5e79c22088ce878edc821dedb4ca5a1cd9f5ef915e9b3cc3053e8faefa";
      size = 45903552;
    };

    x86_64-linux = {
      filename = "zig-x86_64-linux-0.14.1.tar.xz";
      shasum = "24aeeec8af16c381934a6cd7d95c807a8cb2cf7df9fa40d359aa884195c4716c";
      size = 49086504;
    };

    aarch64-linux = {
      filename = "zig-aarch64-linux-0.14.1.tar.xz";
      shasum = "f7a654acc967864f7a050ddacfaa778c7504a0eca8d2b678839c21eea47c992b";
      size = 44954692;
    };

    armv7l-linux = {
      filename = "zig-armv7a-linux-0.14.1.tar.xz";
      shasum = "1b34d9ecfaeb3b360e86c0bc233e1a8a2bbed2d40f2d4f20c12bde2128714324";
      size = 46137456;
    };

    riscv64-linux = {
      filename = "zig-riscv64-linux-0.14.1.tar.xz";
      shasum = "005f214f74dbafb7b4d8bd305f4e9d25048f711d9ec6fa7b3d4fca177e11b882";
      size = 48094380;
    };

    powerpc64le-linux = {
      filename = "zig-powerpc64le-linux-0.14.1.tar.xz";
      shasum = "15523e748efd9224ae164482e5cc1f8c11b035246b9749fb5b00758484f384a1";
      size = 48720956;
    };

    i686-linux = {
      filename = "zig-x86-linux-0.14.1.tar.xz";
      shasum = "4bce6347fa112247443cb0952c19e560d1f90b910506cf895fd07a7b8d1c4a76";
      size = 51643520;
    };

    loongarch64-linux = {
      filename = "zig-loongarch64-linux-0.14.1.tar.xz";
      shasum = "fdc344789be6becbe220bf5ad035156e653cc148f4da270188cbac87729f17e0";
      size = 45825404;
    };

    s390x-linux = {
      filename = "zig-s390x-linux-0.14.1.tar.xz";
      shasum = "8e1bb63532ba22725f0a4a45e5c2920a8af508d8ca81e6007c330eec2b7033a6";
      size = 55602032;
    };

    x86_64-mingw32 = {
      filename = "zig-x86_64-windows-0.14.1.zip";
      shasum = "554f5378228923ffd558eac35e21af020c73789d87afeabf4bfd16f2e6feed2c";
      size = 82229343;
    };

    aarch64-mingw32 = {
      filename = "zig-aarch64-windows-0.14.1.zip";
      shasum = "b5aac0ccc40dd91e8311b1f257717d8e3903b5fefb8f659de6d65a840ad1d0e7";
      size = 78125379;
    };

    i686-mingw32 = {
      filename = "zig-x86-windows-0.14.1.zip";
      shasum = "3ee730c2a5523570dc4dc1b724f3e4f30174ebc1fa109ca472a719586a473b18";
      size = 83983932;
    };
  };

  meta-0_14_0 = {
    version = "0.14.0";
    date = "2025-03-05";
    docs = "https://ziglang.org/documentation/0.14.0/";
    stdDocs = "https://ziglang.org/documentation/0.14.0/std/";
    notes = "https://ziglang.org/download/0.14.0/release-notes.html";

    src = {
      filename = "zig-0.14.0.tar.xz";
      shasum = "c76638c03eb204c4432ae092f6fa07c208567e110fbd4d862d131a7332584046";
      size = 17772188;
    };

    bootstrap = {
      filename = "zig-bootstrap-0.14.0.tar.xz";
      shasum = "bf3fcb22be0b83f4791748adb567d3304779d66d7bf9b1bd557ef6c2e0232807";
      size = 48029040;
    };

    x86_64-darwin = {
      filename = "zig-macos-x86_64-0.14.0.tar.xz";
      shasum = "685816166f21f0b8d6fc7aa6a36e91396dcd82ca6556dfbe3e329deffc01fec3";
      size = 51039964;
    };

    arm64-darwin = {
      filename = "zig-macos-aarch64-0.14.0.tar.xz";
      shasum = "b71e4b7c4b4be9953657877f7f9e6f7ee89114c716da7c070f4a238220e95d7e";
      size = 45902412;
    };

    x86_64-linux = {
      filename = "zig-linux-x86_64-0.14.0.tar.xz";
      shasum = "473ec26806133cf4d1918caf1a410f8403a13d979726a9045b421b685031a982";
      size = 49091960;
    };

    aarch64-linux = {
      filename = "zig-linux-aarch64-0.14.0.tar.xz";
      shasum = "ab64e3ea277f6fc5f3d723dcd95d9ce1ab282c8ed0f431b4de880d30df891e4f";
      size = 44922728;
    };

    armv7l-linux = {
      filename = "zig-linux-armv7a-0.14.0.tar.xz";
      shasum = "a67dbfa9bdf769228ec994f2098698c619f930883ca5ef638f50eee2d7788d10";
      size = 46112980;
    };

    riscv64-linux = {
      filename = "zig-linux-riscv64-0.14.0.tar.xz";
      shasum = "a2b14d3de326d3fd095548ef38bf5a67b15dadd62fbcc90836d63cc4355f8ef7";
      size = 48069188;
    };

    powerpc64le-linux = {
      filename = "zig-linux-powerpc64le-0.14.0.tar.xz";
      shasum = "3eabd60876ebc2748de8eb57b4b8cfa78861ba9bf7c6dd83f4e3e1d271d7c45e";
      size = 48707620;
    };

    i686-linux = {
      filename = "zig-linux-x86-0.14.0.tar.xz";
      shasum = "55d1ba21de5109686ffa675b9cc1dd66930093c202995a637ce3e397816e4c08";
      size = 51621460;
    };

    loongarch64-linux = {
      filename = "zig-linux-loongarch64-0.14.0.tar.xz";
      shasum = "31a2f07df55f8f528b92d540db9aae6c0b38643c34dc1ac33a0111d855e996ae";
      size = 45821860;
    };

    x86_64-mingw32 = {
      filename = "zig-windows-x86_64-0.14.0.zip";
      shasum = "f53e5f9011ba20bbc3e0e6d0a9441b31eb227a97bac0e7d24172f1b8b27b4371";
      size = 82219809;
    };

    aarch64-mingw32 = {
      filename = "zig-windows-aarch64-0.14.0.zip";
      shasum = "03e984383ebb8f85293557cfa9f48ee8698e7c400239570c9ff1aef3bffaf046";
      size = 78113283;
    };

    i686-mingw32 = {
      filename = "zig-windows-x86-0.14.0.zip";
      shasum = "1a867d808cf4fa9184358395d94441390b6b24ee8d00d356ca11ea7cbfd3a4ec";
      size = 83970029;
    };
  };

  meta-0_13_0 = {
    version = "0.13.0";
    date = "2024-06-07";
    docs = "https://ziglang.org/documentation/0.13.0/";
    stdDocs = "https://ziglang.org/documentation/0.13.0/std/";
    notes = "https://ziglang.org/download/0.13.0/release-notes.html";

    src = {
      filename = "zig-0.13.0.tar.xz";
      shasum = "06c73596beeccb71cc073805bdb9c0e05764128f16478fa53bf17dfabc1d4318";
      size = 17220728;
    };

    bootstrap = {
      filename = "zig-bootstrap-0.13.0.tar.xz";
      shasum = "cd446c084b5da7bc42e8ad9b4e1c910a957f2bf3f82bcc02888102cd0827c139";
      size = 46440356;
    };

    x86_64-freebsd = {
      filename = "zig-freebsd-x86_64-0.13.0.tar.xz";
      shasum = "adc1ffc9be56533b2f1c7191f9e435ad55db00414ff2829d951ef63d95aaad8c";
      size = 47177744;
    };

    x86_64-darwin = {
      filename = "zig-macos-x86_64-0.13.0.tar.xz";
      shasum = "8b06ed1091b2269b700b3b07f8e3be3b833000841bae5aa6a09b1a8b4773effd";
      size = 48857012;
    };

    arm64-darwin = {
      filename = "zig-macos-aarch64-0.13.0.tar.xz";
      shasum = "46fae219656545dfaf4dce12fb4e8685cec5b51d721beee9389ab4194d43394c";
      size = 44892040;
    };

    x86_64-linux = {
      filename = "zig-linux-x86_64-0.13.0.tar.xz";
      shasum = "d45312e61ebcc48032b77bc4cf7fd6915c11fa16e4aad116b66c9468211230ea";
      size = 47082308;
    };

    aarch64-linux = {
      filename = "zig-linux-aarch64-0.13.0.tar.xz";
      shasum = "041ac42323837eb5624068acd8b00cd5777dac4cf91179e8dad7a7e90dd0c556";
      size = 43090688;
    };

    armv7l-linux = {
      filename = "zig-linux-armv7a-0.13.0.tar.xz";
      shasum = "4b0550239c2cd884cc03ddeb2b9934708f4b073ad59a96fccbfe09f7e4f54233";
      size = 43998916;
    };

    riscv64-linux = {
      filename = "zig-linux-riscv64-0.13.0.tar.xz";
      shasum = "9f7f3c685894ff80f43eaf3cad1598f4844ac46f4308374237c7f912f7907bb3";
      size = 45540956;
    };

    powerpc64le-linux = {
      filename = "zig-linux-powerpc64le-0.13.0.tar.xz";
      shasum = "6a467622448e830e8f85d20cabed151498af2b0a62f87b8c083b2fe127e60417";
      size = 46574596;
    };

    i686-linux = {
      filename = "zig-linux-x86-0.13.0.tar.xz";
      shasum = "876159cc1e15efb571e61843b39a2327f8925951d48b9a7a03048c36f72180f7";
      size = 52062336;
    };

    x86_64-mingw32 = {
      filename = "zig-windows-x86_64-0.13.0.zip";
      shasum = "d859994725ef9402381e557c60bb57497215682e355204d754ee3df75ee3c158";
      size = 79163968;
    };

    aarch64-mingw32 = {
      filename = "zig-windows-aarch64-0.13.0.zip";
      shasum = "95ff88427af7ba2b4f312f45d2377ce7a033e5e3c620c8caaa396a9aba20efda";
      size = 75119033;
    };

    i686-mingw32 = {
      filename = "zig-windows-x86-0.13.0.zip";
      shasum = "eb3d533c3cf868bff7e74455dc005d18fd836c42e50b27106b31e9fec6dffc4a";
      size = 83274739;
    };
  };

  meta-0_12_1 = {
    version = "0.12.1";
    date = "2024-06-08";
    docs = "https://ziglang.org/documentation/0.12.1/";
    stdDocs = "https://ziglang.org/documentation/0.12.1/std/";

    src = {
      filename = "zig-0.12.1.tar.xz";
      shasum = "cca0bf5686fe1a15405bd535661811fac7663f81664d2204ea4590ce49a6e9ba";
      size = 17110932;
    };

    bootstrap = {
      filename = "zig-bootstrap-0.12.1.tar.xz";
      shasum = "e533e2cb6ef60edda0ae3f2ca5c6504557db6e985e3c3a80159beb32279ed341";
      size = 45542004;
    };

    x86_64-freebsd = {
      filename = "zig-freebsd-x86_64-0.12.1.tar.xz";
      shasum = "30eaa28fa7bc21d01f88528d75ae4b392ae4970406675d5ac712a4937a605123";
      size = 45590080;
    };

    x86_64-darwin = {
      filename = "zig-macos-x86_64-0.12.1.tar.xz";
      shasum = "68f309c6e431d56eb42648d7fe86e8028a23464d401a467831e27c26f1a8d9c9";
      size = 47202232;
    };

    arm64-darwin = {
      filename = "zig-macos-aarch64-0.12.1.tar.xz";
      shasum = "6587860dbbc070e1ee069e1a3d18ced83b7ba7a80bf67b2c57caf7c9ce5208b1";
      size = 43451512;
    };

    x86_64-linux = {
      filename = "zig-linux-x86_64-0.12.1.tar.xz";
      shasum = "8860fc9725c2d9297a63008f853e9b11e3c5a2441217f99c1e3104cc6fa4a443";
      size = 45512024;
    };

    aarch64-linux = {
      filename = "zig-linux-aarch64-0.12.1.tar.xz";
      shasum = "27d4fef393e8d8b5f3b1d19f4dd43bfdb469b4ed17bbc4c2283c1b1fe650ef7f";
      size = 41867324;
    };

    armv7l-linux = {
      filename = "zig-linux-armv7a-0.12.1.tar.xz";
      shasum = "27493c922fd1454137ed6cbe6b6bec00352838fcd32e6e74f4f9187011816157";
      size = 42665508;
    };

    riscv64-linux = {
      filename = "zig-linux-riscv64-0.12.1.tar.xz";
      shasum = "463511a863acc16911cff6801de97623e6de296aab7b15dcda5f6fd078b400b5";
      size = 43932908;
    };

    powerpc64le-linux = {
      filename = "zig-linux-powerpc64le-0.12.1.tar.xz";
      shasum = "462d6f10350f3c5d6fc4c9d6cfdede93d69d0103af026889a15f65c5de791d39";
      size = 45227716;
    };

    i686-linux = {
      filename = "zig-linux-x86-0.12.1.tar.xz";
      shasum = "c36ac019ca0fc3167e50d17e2affd3d072a06c519761737d0639adfdf2dcfddd";
      size = 50555428;
    };

    x86_64-mingw32 = {
      filename = "zig-windows-x86_64-0.12.1.zip";
      shasum = "52459b147c2de4d7c28f6b1a4b3d571c114e96836bf8e31c953a7d2f5e94251c";
      size = 76470574;
    };

    aarch64-mingw32 = {
      filename = "zig-windows-aarch64-0.12.1.zip";
      shasum = "e1286114a11be4695a6ad5cf0ba6a0e5f489bb3b029a5237de93598133f0c13a";
      size = 72998386;
    };

    i686-mingw32 = {
      filename = "zig-windows-x86-0.12.1.zip";
      shasum = "4f0cc9258527e7b8bcf742772b3069122086a5cd857b38a1c08002462ac81f80";
      size = 80979711;
    };
  };

  meta-0_12_0 = {
    version = "0.12.0";
    date = "2024-04-20";
    docs = "https://ziglang.org/documentation/0.12.0/";
    stdDocs = "https://ziglang.org/documentation/0.12.0/std/";
    notes = "https://ziglang.org/download/0.12.0/release-notes.html";

    src = {
      filename = "zig-0.12.0.tar.xz";
      shasum = "a6744ef84b6716f976dad923075b2f54dc4f785f200ae6c8ea07997bd9d9bd9a";
      size = 17099152;
    };

    bootstrap = {
      filename = "zig-bootstrap-0.12.0.tar.xz";
      shasum = "3efc643d56421fa68072af94d5512cb71c61acf1c32512f77c0b4590bff63187";
      size = 45527312;
    };

    x86_64-freebsd = {
      filename = "zig-freebsd-x86_64-0.12.0.tar.xz";
      shasum = "bd49957d1157850b337ee1cf3c00af83585cff98e1ebc3c524a267e7422a2d7b";
      size = 45578364;
    };

    x86_64-darwin = {
      filename = "zig-macos-x86_64-0.12.0.tar.xz";
      shasum = "4d411bf413e7667821324da248e8589278180dbc197f4f282b7dbb599a689311";
      size = 47185720;
    };

    arm64-darwin = {
      filename = "zig-macos-aarch64-0.12.0.tar.xz";
      shasum = "294e224c14fd0822cfb15a35cf39aa14bd9967867999bf8bdfe3db7ddec2a27f";
      size = 43447724;
    };

    x86_64-linux = {
      filename = "zig-linux-x86_64-0.12.0.tar.xz";
      shasum = "c7ae866b8a76a568e2d5cfd31fe89cdb629bdd161fdd5018b29a4a0a17045cad";
      size = 45480516;
    };

    aarch64-linux = {
      filename = "zig-linux-aarch64-0.12.0.tar.xz";
      shasum = "754f1029484079b7e0ca3b913a0a2f2a6afd5a28990cb224fe8845e72f09de63";
      size = 41849060;
    };

    armv7l-linux = {
      filename = "zig-linux-armv7a-0.12.0.tar.xz";
      shasum = "b48221f4c64416d257f0f9f77d8727dccf7de92aeabe59744ee6e70d650a97bc";
      size = 42638808;
    };

    riscv64-linux = {
      filename = "zig-linux-riscv64-0.12.0.tar.xz";
      shasum = "bb2d1a78b01595a9c00ffd2e12ab46e32f8b6798f76aec643ff78e5b4f5c5afd";
      size = 43917444;
    };

    powerpc64le-linux = {
      filename = "zig-linux-powerpc64le-0.12.0.tar.xz";
      shasum = "9218beecfb9250e9eff863f58f987dca7077e3258dd263c40269086127f9679b";
      size = 45216736;
    };

    i686-linux = {
      filename = "zig-linux-x86-0.12.0.tar.xz";
      shasum = "fb752fceb88749a80d625a6efdb23bea8208962b5150d6d14c92d20efda629a5";
      size = 50498940;
    };

    x86_64-mingw32 = {
      filename = "zig-windows-x86_64-0.12.0.zip";
      shasum = "2199eb4c2000ddb1fba85ba78f1fcf9c1fb8b3e57658f6a627a8e513131893f5";
      size = 76442958;
    };

    aarch64-mingw32 = {
      filename = "zig-windows-aarch64-0.12.0.zip";
      shasum = "04c6b92689241ca7a8a59b5f12d2ca2820c09d5043c3c4808b7e93e41c7bf97b";
      size = 72976876;
    };

    i686-mingw32 = {
      filename = "zig-windows-x86-0.12.0.zip";
      shasum = "497dc9fd415cadf948872f137d6cc0870507488f79db9547b8f2adb73cda9981";
      size = 80950440;
    };
  };

  meta-0_11_0 = {
    version = "0.11.0";
    date = "2023-08-04";
    docs = "https://ziglang.org/documentation/0.11.0/";
    stdDocs = "https://ziglang.org/documentation/0.11.0/std/";
    notes = "https://ziglang.org/download/0.11.0/release-notes.html";

    src = {
      filename = "zig-0.11.0.tar.xz";
      shasum = "72014e700e50c0d3528cef3adf80b76b26ab27730133e8202716a187a799e951";
      size = 15275316;
    };

    bootstrap = {
      filename = "zig-bootstrap-0.11.0.tar.xz";
      shasum = "38dd9e17433c7ce5687c48fa0a757462cbfcbe75d9d5087d14ebbe00efd21fdc";
      size = 43227592;
    };

    x86_64-freebsd = {
      filename = "zig-freebsd-x86_64-0.11.0.tar.xz";
      shasum = "ea430327f9178377b79264a1d492868dcff056cd76d43a6fb00719203749e958";
      size = 46432140;
    };

    x86_64-darwin = {
      filename = "zig-macos-x86_64-0.11.0.tar.xz";
      shasum = "1c1c6b9a906b42baae73656e24e108fd8444bb50b6e8fd03e9e7a3f8b5f05686";
      size = 47189164;
    };

    arm64-darwin = {
      filename = "zig-macos-aarch64-0.11.0.tar.xz";
      shasum = "c6ebf927bb13a707d74267474a9f553274e64906fd21bf1c75a20bde8cadf7b2";
      size = 43855096;
    };

    x86_64-linux = {
      filename = "zig-linux-x86_64-0.11.0.tar.xz";
      shasum = "2d00e789fec4f71790a6e7bf83ff91d564943c5ee843c5fd966efc474b423047";
      size = 44961892;
    };

    aarch64-linux = {
      filename = "zig-linux-aarch64-0.11.0.tar.xz";
      shasum = "956eb095d8ba44ac6ebd27f7c9956e47d92937c103bf754745d0a39cdaa5d4c6";
      size = 41492432;
    };

    armv7l-linux = {
      filename = "zig-linux-armv7a-0.11.0.tar.xz";
      shasum = "aebe8bbeca39f13f9b7304465f9aee01ab005d243836bd40f4ec808093dccc9b";
      size = 42240664;
    };

    riscv64-linux = {
      filename = "zig-linux-riscv64-0.11.0.tar.xz";
      shasum = "24a478937eddb507e96d60bd4da00de9092b3f0920190eb45c4c99c946b00ed5";
      size = 43532324;
    };

    powerpc64le-linux = {
      filename = "zig-linux-powerpc64le-0.11.0.tar.xz";
      shasum = "75260e87325e820a278cf9e74f130c7b3d84c0b5197afb2e3c85eff3fcedd48d";
      size = 44656184;
    };

    powerpc-linux = {
      filename = "zig-linux-powerpc-0.11.0.tar.xz";
      shasum = "70a5f9668a66fb2a91a7c3488b15bcb568e1f9f44b95cd10075c138ad8c42864";
      size = 44539972;
    };

    i686-linux = {
      filename = "zig-linux-x86-0.11.0.tar.xz";
      shasum = "7b0dc3e0e070ae0e0d2240b1892af6a1f9faac3516cae24e57f7a0e7b04662a8";
      size = 49824456;
    };

    x86_64-mingw32 = {
      filename = "zig-windows-x86_64-0.11.0.zip";
      shasum = "142caa3b804d86b4752556c9b6b039b7517a08afa3af842645c7e2dcd125f652";
      size = 77216743;
    };

    aarch64-mingw32 = {
      filename = "zig-windows-aarch64-0.11.0.zip";
      shasum = "5d4bd13db5ecb0ddc749231e00f125c1d31087d708e9ff9b45c4f4e13e48c661";
      size = 73883137;
    };

    i686-mingw32 = {
      filename = "zig-windows-x86-0.11.0.zip";
      shasum = "e72b362897f28c671633e650aa05289f2e62b154efcca977094456c8dac3aefa";
      size = 81576961;
    };
  };

  meta-0_10_1 = {
    version = "0.10.1";
    date = "2023-01-19";
    docs = "https://ziglang.org/documentation/0.10.1/";
    stdDocs = "https://ziglang.org/documentation/0.10.1/std/";
    notes = "https://ziglang.org/download/0.10.1/release-notes.html";

    src = {
      filename = "zig-0.10.1.tar.xz";
      shasum = "69459bc804333df077d441ef052ffa143d53012b655a51f04cfef1414c04168c";
      size = 15143112;
    };

    bootstrap = {
      filename = "zig-bootstrap-0.10.1.tar.xz";
      shasum = "9f5781210b9be8f832553d160851635780f9bd71816065351ab29cfd8968f5e9";
      size = 43971816;
    };

    x86_64-darwin = {
      filename = "zig-macos-x86_64-0.10.1.tar.xz";
      shasum = "02483550b89d2a3070c2ed003357fd6e6a3059707b8ee3fbc0c67f83ca898437";
      size = 45119596;
    };

    arm64-darwin = {
      filename = "zig-macos-aarch64-0.10.1.tar.xz";
      shasum = "b9b00477ec5fa1f1b89f35a7d2a58688e019910ab80a65eac2a7417162737656";
      size = 40517896;
    };

    x86_64-linux = {
      filename = "zig-linux-x86_64-0.10.1.tar.xz";
      shasum = "6699f0e7293081b42428f32c9d9c983854094bd15fee5489f12c4cf4518cc380";
      size = 44085596;
    };

    aarch64-linux = {
      filename = "zig-linux-aarch64-0.10.1.tar.xz";
      shasum = "db0761664f5f22aa5bbd7442a1617dd696c076d5717ddefcc9d8b95278f71f5d";
      size = 40321280;
    };

    riscv64-linux = {
      filename = "zig-linux-riscv64-0.10.1.tar.xz";
      shasum = "9db5b59a5112b8beb995094ba800e88b0060e9cf7cfadf4dc3e666c9010dc77b";
      size = 42196008;
    };

    i686-linux = {
      filename = "zig-linux-i386-0.10.1.tar.xz";
      shasum = "8c710ca5966b127b0ee3efba7310601ee57aab3dd6052a082ebc446c5efb2316";
      size = 48367388;
    };

    x86_64-mingw32 = {
      filename = "zig-windows-x86_64-0.10.1.zip";
      shasum = "5768004e5e274c7969c3892e891596e51c5df2b422d798865471e05049988125";
      size = 73259729;
    };

    aarch64-mingw32 = {
      filename = "zig-windows-aarch64-0.10.1.zip";
      shasum = "ece93b0d77b2ab03c40db99ef7ccbc63e0b6bd658af12b97898960f621305428";
      size = 69417459;
    };
  };

  meta-0_10_0 = {
    version = "0.10.0";
    date = "2022-10-31";
    docs = "https://ziglang.org/documentation/0.10.0/";
    stdDocs = "https://ziglang.org/documentation/0.10.0/std/";
    notes = "https://ziglang.org/download/0.10.0/release-notes.html";

    src = {
      filename = "zig-0.10.0.tar.xz";
      shasum = "d8409f7aafc624770dcd050c8fa7e62578be8e6a10956bca3c86e8531c64c136";
      size = 14530912;
    };

    bootstrap = {
      filename = "zig-bootstrap-0.10.0.tar.xz";
      shasum = "c13dc70c4ff4c09f749adc0d473cbd3942991dd4d1bd2d860fbf257d8c1bbabf";
      size = 45625516;
    };

    x86_64-freebsd = {
      filename = "zig-freebsd-x86_64-0.10.0.tar.xz";
      shasum = "dd77afa2a8676afbf39f7d6068eda81b0723afd728642adaac43cb2106253d65";
      size = 44056504;
    };

    aarch64-linux = {
      filename = "zig-linux-aarch64-0.10.0.tar.xz";
      shasum = "09ef50c8be73380799804169197820ee78760723b0430fa823f56ed42b06ea0f";
      size = 40387688;
    };

    armv7l-linux = {
      filename = "zig-linux-armv7a-0.10.0.tar.xz";
      shasum = "7201b2e89cd7cc2dde95d39485fd7d5641ba67dc6a9a58c036cb4c308d2e82de";
      size = 50805936;
    };

    i686-linux = {
      filename = "zig-linux-i386-0.10.0.tar.xz";
      shasum = "dac8134f1328c50269f3e50b334298ec7916cb3b0ef76927703ddd1c96fd0115";
      size = 48451732;
    };

    riscv64-linux = {
      filename = "zig-linux-riscv64-0.10.0.tar.xz";
      shasum = "2a126f3401a7a7efc4b454f0a85c133db1af5a9dfee117f172213b7cbd47bfba";
      size = 42272968;
    };

    x86_64-linux = {
      filename = "zig-linux-x86_64-0.10.0.tar.xz";
      shasum = "631ec7bcb649cd6795abe40df044d2473b59b44e10be689c15632a0458ddea55";
      size = 44142400;
    };

    arm64-darwin = {
      filename = "zig-macos-aarch64-0.10.0.tar.xz";
      shasum = "02f7a7839b6a1e127eeae22ea72c87603fb7298c58bc35822a951479d53c7557";
      size = 40602664;
    };

    x86_64-darwin = {
      filename = "zig-macos-x86_64-0.10.0.tar.xz";
      shasum = "3a22cb6c4749884156a94ea9b60f3a28cf4e098a69f08c18fbca81c733ebfeda";
      size = 45175104;
    };

    x86_64-mingw32 = {
      filename = "zig-windows-x86_64-0.10.0.zip";
      shasum = "a66e2ff555c6e48781de1bcb0662ef28ee4b88af3af2a577f7b1950e430897ee";
      size = 73181558;
    };

    aarch64-mingw32 = {
      filename = "zig-windows-aarch64-0.10.0.zip";
      shasum = "1bbda8d123d44f3ae4fa90d0da04b1e9093c3f9ddae3429a4abece1e1c0bf19a";
      size = 69332389;
    };
  };

  meta-0_9_1 = {
    version = "0.9.1";
    date = "2022-02-14";
    docs = "https://ziglang.org/documentation/0.9.1/";
    stdDocs = "https://ziglang.org/documentation/0.9.1/std/";
    notes = "https://ziglang.org/download/0.9.1/release-notes.html";

    src = {
      filename = "zig-0.9.1.tar.xz";
      shasum = "38cf4e84481f5facc766ba72783e7462e08d6d29a5d47e3b75c8ee3142485210";
      size = 13940828;
    };

    bootstrap = {
      filename = "zig-bootstrap-0.9.1.tar.xz";
      shasum = "0a8e221c71860d8975c15662b3ed3bd863e81c4fe383455a596e5e0e490d6109";
      size = 42488812;
    };

    x86_64-freebsd = {
      filename = "zig-freebsd-x86_64-0.9.1.tar.xz";
      shasum = "4e06009bd3ede34b72757eec1b5b291b30aa0d5046dadd16ecb6b34a02411254";
      size = 39028848;
    };

    aarch64-linux = {
      filename = "zig-linux-aarch64-0.9.1.tar.xz";
      shasum = "5d99a39cded1870a3fa95d4de4ce68ac2610cca440336cfd252ffdddc2b90e66";
      size = 37034860;
    };

    armv7l-linux = {
      filename = "zig-linux-armv7a-0.9.1.tar.xz";
      shasum = "6de64456cb4757a555816611ea697f86fba7681d8da3e1863fa726a417de49be";
      size = 37974652;
    };

    i686-linux = {
      filename = "zig-linux-i386-0.9.1.tar.xz";
      shasum = "e776844fecd2e62fc40d94718891057a1dbca1816ff6013369e9a38c874374ca";
      size = 44969172;
    };

    riscv64-linux = {
      filename = "zig-linux-riscv64-0.9.1.tar.xz";
      shasum = "208dea53662c2c52777bd9e3076115d2126a4f71aed7f2ff3b8fe224dc3881aa";
      size = 39390868;
    };

    x86_64-linux = {
      filename = "zig-linux-x86_64-0.9.1.tar.xz";
      shasum = "be8da632c1d3273f766b69244d80669fe4f5e27798654681d77c992f17c237d7";
      size = 41011464;
    };

    arm64-darwin = {
      filename = "zig-macos-aarch64-0.9.1.tar.xz";
      shasum = "8c473082b4f0f819f1da05de2dbd0c1e891dff7d85d2c12b6ee876887d438287";
      size = 38995640;
    };

    x86_64-darwin = {
      filename = "zig-macos-x86_64-0.9.1.tar.xz";
      shasum = "2d94984972d67292b55c1eb1c00de46580e9916575d083003546e9a01166754c";
      size = 43713044;
    };

    i686-mingw32 = {
      filename = "zig-windows-i386-0.9.1.zip";
      shasum = "74a640ed459914b96bcc572183a8db687bed0af08c30d2ea2f8eba03ae930f69";
      size = 67929868;
    };

    x86_64-mingw32 = {
      filename = "zig-windows-x86_64-0.9.1.zip";
      shasum = "443da53387d6ae8ba6bac4b3b90e9fef4ecbe545e1c5fa3a89485c36f5c0e3a2";
      size = 65047697;
    };

    aarch64-mingw32 = {
      filename = "zig-windows-aarch64-0.9.1.zip";
      shasum = "621bf95f54dc3ff71466c5faae67479419951d7489e40e87fd26d195825fb842";
      size = 61478151;
    };
  };

  meta-0_9_0 = {
    version = "0.9.0";
    date = "2021-12-20";
    docs = "https://ziglang.org/documentation/0.9.0/";
    stdDocs = "https://ziglang.org/documentation/0.9.0/std/";
    notes = "https://ziglang.org/download/0.9.0/release-notes.html";

    src = {
      filename = "zig-0.9.0.tar.xz";
      shasum = "cd1be83b12f8269cc5965e59877b49fdd8fa638efb6995ac61eb4cea36a2e381";
      size = 13928772;
    };

    bootstrap = {
      filename = "zig-bootstrap-0.9.0.tar.xz";
      shasum = "16b0bdf0bc0a5ed1e0950e08481413d806192e06443a512347526647b2baeabc";
      size = 42557736;
    };

    x86_64-freebsd = {
      filename = "zig-freebsd-x86_64-0.9.0.tar.xz";
      shasum = "c95afe679b7cc4110dc2ecd3606c83a699718b7a958d6627f74c20886333e194";
      size = 41293236;
    };

    aarch64-linux = {
      filename = "zig-linux-aarch64-0.9.0.tar.xz";
      shasum = "1524fedfdbade2dbc9bae1ed98ad38fa7f2114c9a3e94da0d652573c75efbc5a";
      size = 40008396;
    };

    armv7l-linux = {
      filename = "zig-linux-armv7a-0.9.0.tar.xz";
      shasum = "50225dee6e6448a63ee96383a34d9fe3bba34ae8da1a0c8619bde2cdfc1df87d";
      size = 41196876;
    };

    i686-linux = {
      filename = "zig-linux-i386-0.9.0.tar.xz";
      shasum = "b0dcf688349268c883292acdd55eaa3c13d73b9146e4b990fad95b84a2ac528b";
      size = 47408656;
    };

    riscv64-linux = {
      filename = "zig-linux-riscv64-0.9.0.tar.xz";
      shasum = "85466de07504767ed37f59782672ad41bbdf43d6480fafd07f45543278b07620";
      size = 44171420;
    };

    x86_64-linux = {
      filename = "zig-linux-x86_64-0.9.0.tar.xz";
      shasum = "5c55344a877d557fb1b28939785474eb7f4f2f327aab55293998f501f7869fa6";
      size = 43420796;
    };

    arm64-darwin = {
      filename = "zig-macos-aarch64-0.9.0.tar.xz";
      shasum = "3991c70594d61d09fb4b316157a7c1d87b1d4ec159e7a5ecd11169ff74cad832";
      size = 39013392;
    };

    x86_64-darwin = {
      filename = "zig-macos-x86_64-0.9.0.tar.xz";
      shasum = "c5280eeec4d6e5ea5ce5b448dc9a7c4bdd85ecfed4c1b96aa0835e48b36eccf0";
      size = 43764596;
    };

    i686-mingw32 = {
      filename = "zig-windows-i386-0.9.0.zip";
      shasum = "bb839434afc75092015cf4c33319d31463c18512bc01dd719aedf5dcbc368466";
      size = 67946715;
    };

    x86_64-mingw32 = {
      filename = "zig-windows-x86_64-0.9.0.zip";
      shasum = "084ea2646850aaf068234b0f1a92b914ed629be47075e835f8a67d55c21d880e";
      size = 65045849;
    };

    aarch64-mingw32 = {
      filename = "zig-windows-aarch64-0.9.0.zip";
      shasum = "f9018725e3fb2e8992b17c67034726971156eb190685018a9ac8c3a9f7a22340";
      size = 61461921;
    };
  };

  meta-0_8_1 = {
    version = "0.8.1";
    date = "2021-09-06";
    docs = "https://ziglang.org/documentation/0.8.1/";
    stdDocs = "https://ziglang.org/documentation/0.8.1/std/";
    notes = "https://ziglang.org/download/0.8.1/release-notes.html";

    src = {
      filename = "zig-0.8.1.tar.xz";
      shasum = "8c428e14a0a89cb7a15a6768424a37442292858cdb695e2eb503fa3c7bf47f1a";
      size = 12650228;
    };

    bootstrap = {
      filename = "zig-bootstrap-0.8.1.tar.xz";
      shasum = "fa1239247f830ecd51c42537043f5220e4d1dfefdc54356fa419616a0efb3902";
      size = 43613464;
    };

    x86_64-freebsd = {
      filename = "zig-freebsd-x86_64-0.8.1.tar.xz";
      shasum = "fc4f6478bcf3a9fce1b8ef677a91694f476dd35be6d6c9c4f44a8b76eedbe176";
      size = 39150924;
    };

    aarch64-linux = {
      filename = "zig-linux-aarch64-0.8.1.tar.xz";
      shasum = "2166dc9f2d8df387e8b4122883bb979d739281e1ff3f3d5483fec3a23b957510";
      size = 37605932;
    };

    armv7l-linux = {
      filename = "zig-linux-armv7a-0.8.1.tar.xz";
      shasum = "5ba58141805e2519f38cf8e715933cbf059f4f3dade92c71838cce341045de05";
      size = 39185876;
    };

    i686-linux = {
      filename = "zig-linux-i386-0.8.1.tar.xz";
      shasum = "2f3e84f30492b5f1c5f97cecc0166f07a8a8d50c5f85dbb3a6ef2a4ee6f915e6";
      size = 44782932;
    };

    riscv64-linux = {
      filename = "zig-linux-riscv64-0.8.1.tar.xz";
      shasum = "4adfaf147b025917c03367462fe5018aaa9edbc6439ef9cd0da2b074ae960554";
      size = 41234480;
    };

    x86_64-linux = {
      filename = "zig-linux-x86_64-0.8.1.tar.xz";
      shasum = "6c032fc61b5d77a3f3cf781730fa549f8f059ffdb3b3f6ad1c2994d2b2d87983";
      size = 41250060;
    };

    arm64-darwin = {
      filename = "zig-macos-aarch64-0.8.1.tar.xz";
      shasum = "5351297e3b8408213514b29c0a938002c5cf9f97eee28c2f32920e1227fd8423";
      size = 35340712;
    };

    x86_64-darwin = {
      filename = "zig-macos-x86_64-0.8.1.tar.xz";
      shasum = "16b0e1defe4c1807f2e128f72863124bffdd906cefb21043c34b673bf85cd57f";
      size = 39946200;
    };

    i686-mingw32 = {
      filename = "zig-windows-i386-0.8.1.zip";
      shasum = "099605051eb0452a947c8eab8fbbc7e43833c8376d267e94e41131c289a1c535";
      size = 64152358;
    };

    x86_64-mingw32 = {
      filename = "zig-windows-x86_64-0.8.1.zip";
      shasum = "43573db14cd238f7111d6bdf37492d363f11ecd1eba802567a172f277d003926";
      size = 61897838;
    };
  };

  meta-0_8_0 = {
    version = "0.8.0";
    date = "2021-06-04";
    docs = "https://ziglang.org/documentation/0.8.0/";
    stdDocs = "https://ziglang.org/documentation/0.8.0/std/";
    notes = "https://ziglang.org/download/0.8.0/release-notes.html";

    src = {
      filename = "zig-0.8.0.tar.xz";
      shasum = "03a828d00c06b2e3bb8b7ff706997fd76bf32503b08d759756155b6e8c981e77";
      size = 12614896;
    };

    bootstrap = {
      filename = "zig-bootstrap-0.8.0.tar.xz";
      shasum = "10600bc9c01f92e343f40d6ecc0ad05d67d27c3e382bce75524c0639cd8ca178";
      size = 43574248;
    };

    x86_64-freebsd = {
      filename = "zig-freebsd-x86_64-0.8.0.tar.xz";
      shasum = "0d3ccc436c8c0f50fd55462f72f8492d98723c7218ffc2a8a1831967d81b4bdc";
      size = 39125332;
    };

    aarch64-linux = {
      filename = "zig-linux-aarch64-0.8.0.tar.xz";
      shasum = "ee204ca2c2037952cf3f8b10c609373a08a291efa4af7b3c73be0f2b27720470";
      size = 37575428;
    };

    armv7l-linux = {
      filename = "zig-linux-armv7a-0.8.0.tar.xz";
      shasum = "d00b8bd97b79f45d6f5da956983bafeaa082e6c2ae8c6e1c6d4faa22fa29b320";
      size = 38884212;
    };

    i686-linux = {
      filename = "zig-linux-i386-0.8.0.tar.xz";
      shasum = "96e43ee6ed81c3c63401f456bd1c58ee6d42373a43cb324f5cf4974ca0998865";
      size = 42136032;
    };

    riscv64-linux = {
      filename = "zig-linux-riscv64-0.8.0.tar.xz";
      shasum = "75997527a78cdab64c40c43d9df39c01c4cdb557bb3992a869838371a204cfea";
      size = 40016268;
    };

    x86_64-linux = {
      filename = "zig-linux-x86_64-0.8.0.tar.xz";
      shasum = "502625d3da3ae595c5f44a809a87714320b7a40e6dff4a895b5fa7df3391d01e";
      size = 41211184;
    };

    arm64-darwin = {
      filename = "zig-macos-aarch64-0.8.0.tar.xz";
      shasum = "b32d13f66d0e1ff740b3326d66a469ee6baddbd7211fa111c066d3bd57683111";
      size = 35292180;
    };

    x86_64-darwin = {
      filename = "zig-macos-x86_64-0.8.0.tar.xz";
      shasum = "279f9360b5cb23103f0395dc4d3d0d30626e699b1b4be55e98fd985b62bc6fbe";
      size = 39969312;
    };

    i686-mingw32 = {
      filename = "zig-windows-i386-0.8.0.zip";
      shasum = "b6ec9aa6cd6f3872fcb30d43ff411802d82008a0c4142ee49e208a09b2c1c5fe";
      size = 61507213;
    };

    x86_64-mingw32 = {
      filename = "zig-windows-x86_64-0.8.0.zip";
      shasum = "8580fbbf3afb72e9b495c7f8aeac752a03475ae0bbcf5d787f3775c7e1f4f807";
      size = 61766193;
    };
  };
in
{
  latest = bin meta-0_15_1;
  src-latest = src meta-0_15_1 llvmPackages_20;
  master = bin meta-master;
  src-master = src meta-master llvmPackages_21;
  "0_15_1" = bin meta-0_15_1;
  src-0_15_1 = src meta-0_15_1 llvmPackages_20;
  "0_14_1" = bin meta-0_14_1;
  src-0_14_1 = src meta-0_14_1 llvmPackages_19;
  "0_14_0" = bin meta-0_14_0;
  src-0_14_0 = src meta-0_14_0 llvmPackages_19;
  "0_13_0" = bin meta-0_13_0;
  src-0_13_0 = src meta-0_13_0 llvmPackages_18;
  "0_12_1" = bin meta-0_12_1;
  "0_12_0" = bin meta-0_12_0;
  "0_11_0" = bin meta-0_11_0;
  "0_10_1" = bin meta-0_10_1;
  "0_10_0" = bin meta-0_10_0;
  "0_9_1" = bin meta-0_9_1;
  "0_9_0" = bin meta-0_9_0;
  "0_8_1" = bin meta-0_8_1;
  "0_8_0" = bin meta-0_8_0;
}
