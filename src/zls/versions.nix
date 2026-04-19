{
  zlsBin,
}:

let
  bin = release: zlsBin { inherit release; };

  meta-0_16_0 = {
    version = "0.16.0";
    date = "2026-04-16";

    aarch64-linux = {
      filename = "zls-aarch64-linux-0.16.0.tar.xz";
      shasum = "430cd293d201eb70ae2519dbc96c854bf8791b8df7fc9392e8d2dc9680a2bed7";
      size = 3814984;
    };

    arm64-darwin = {
      filename = "zls-aarch64-macos-0.16.0.tar.xz";
      shasum = "b93ec549f8558a7e85984a840e9276d274f1059b54ade4254296ef4982958359";
      size = 1080896;
    };

    aarch64-mingw32 = {
      filename = "zls-aarch64-windows-0.16.0.zip";
      shasum = "ef4c5ccb93c80c9f023105c5f558ae8774ac6668d560ba6f92a2f87d95df2311";
      size = 4563060;
    };

    armv7l-linux = {
      filename = "zls-arm-linux-0.16.0.tar.xz";
      shasum = "7cf8d11f914127809b89254ad97e4b96d84294370418954a49b78bd623d3c55e";
      size = 3932748;
    };

    loongarch64-linux = {
      filename = "zls-loongarch64-linux-0.16.0.tar.xz";
      shasum = "91128eb73e475cb85f81c40182cb6ce24457b29c857ceb8619205e6cc4bc7b96";
      size = 3711704;
    };

    riscv64-linux = {
      filename = "zls-riscv64-linux-0.16.0.tar.xz";
      shasum = "2764ac1303a5b398569df0e8702c6f6ef86da915aeff4bf9dd0c22bc55324288";
      size = 4805724;
    };

    i686-linux = {
      filename = "zls-x86-linux-0.16.0.tar.xz";
      shasum = "2f7965da884d74d9f7e8b8ef1208ae137084680ddf8580473ff412f62a4051a8";
      size = 4059840;
    };

    i686-mingw32 = {
      filename = "zls-x86-windows-0.16.0.zip";
      shasum = "ecb2870979b35143aa5e7ce92d3b69362a76fd7126c8f950a5f8a7f99a77416f";
      size = 4920545;
    };

    x86_64-linux = {
      filename = "zls-x86_64-linux-0.16.0.tar.xz";
      shasum = "ded6d562a0b86ee878b1ddf70ffab2797ce3cdca3b02d6077548f9d56dff96b6";
      size = 4016620;
    };

    x86_64-darwin = {
      filename = "zls-x86_64-macos-0.16.0.tar.xz";
      shasum = "49f716ea96c1aadaecaa5d9c0a50874cbcf443dc42b825f1e7ee35499ad3eb96";
      size = 1248492;
    };

    x86_64-mingw32 = {
      filename = "zls-x86_64-windows-0.16.0.zip";
      shasum = "35cbb7163224e8cf92d21099c1b1391f2aba927f25d389f021b13a21d40b96dd";
      size = 4801390;
    };

    wasm32-wasi = {
      filename = "zls-wasm32-wasi-0.16.0.tar.xz";
      shasum = "e992d135d74468ac6bac2907ce31092b2ad24a2faa8ef4e93d1131a51666fd0a";
      size = 2499692;
    };

    powerpc64le-linux = {
      filename = "zls-powerpc64le-linux-0.16.0.tar.xz";
      shasum = "d51289187aaa892eb266baaa6c1d7f2a30f6d195eaa295c6f54eef17214f03fa";
      size = 3897484;
    };

    s390x-linux = {
      filename = "zls-s390x-linux-0.16.0.tar.xz";
      shasum = "e4f4dda6fbd9311f86fcc81480ee2fa9bb28697376669173a825cc67711a635a";
      size = 4300556;
    };
  };

  meta-0_15_1 = {
    version = "0.15.1";
    date = "2025-12-05";

    aarch64-linux = {
      filename = "zls-aarch64-linux-0.15.1.tar.xz";
      shasum = "a2daa860a0e0cd1410491ff9703c6aaca96defd833b88af6a9811d6ff04fc13b";
      size = 3563348;
    };

    arm64-darwin = {
      filename = "zls-aarch64-macos-0.15.1.tar.xz";
      shasum = "a6b3f1b10d77f37f3b9d962093f030334b083f48eb2607a4b3ccb72de2958133";
      size = 998352;
    };

    aarch64-mingw32 = {
      filename = "zls-aarch64-windows-0.15.1.zip";
      shasum = "46f7c224db4045e5948bbb0608313539343d46466030f8d253488a75b5aabd44";
      size = 4260676;
    };

    armv7l-linux = {
      filename = "zls-arm-linux-0.15.1.tar.xz";
      shasum = "4c57284eb605e51ed895e30a07c40579473f56390338af2caa35ce25a2264c8c";
      size = 3680352;
    };

    loongarch64-linux = {
      filename = "zls-loongarch64-linux-0.15.1.tar.xz";
      shasum = "01cd9378af1a4ab3c06984800d041d4b5005ba1bfc3c2d4ca47fdff4eb23fa1c";
      size = 3400364;
    };

    riscv64-linux = {
      filename = "zls-riscv64-linux-0.15.1.tar.xz";
      shasum = "6ffd523b08b3b1c18ef061653e29e08e7561633c60dcd41f4af2e9985aa32daf";
      size = 4444976;
    };

    i686-linux = {
      filename = "zls-x86-linux-0.15.1.tar.xz";
      shasum = "b0a2fd145bd19ed274a4cd523cd682ba00894c549a083aef95cbbde7fa1a2c45";
      size = 3755116;
    };

    i686-mingw32 = {
      filename = "zls-x86-windows-0.15.1.zip";
      shasum = "31fef25b6a398d41e59ee12ed176e7b5deeb769d12dcba2aac492907da62389d";
      size = 4527967;
    };

    x86_64-linux = {
      filename = "zls-x86_64-linux-0.15.1.tar.xz";
      shasum = "3bb38f522cb23213e8c075ac6b170273fe49b4274b8c12b034cc496407400067";
      size = 3794532;
    };

    x86_64-darwin = {
      filename = "zls-x86_64-macos-0.15.1.tar.xz";
      shasum = "b76aa724be3f69799f08063f84e93b8b5925f6bf6007f251a2fbea4f9fc244dd";
      size = 1170436;
    };

    x86_64-mingw32 = {
      filename = "zls-x86_64-windows-0.15.1.zip";
      shasum = "41b20c8e2952c95385ce316c3e8000178a6deb4857893f2f6d8078b1453c0f54";
      size = 4483562;
    };

    wasm32-wasi = {
      filename = "zls-wasm32-wasi-0.15.1.tar.xz";
      shasum = "22985ff458f947042bcdc06a6ace19bc2d75df0e770c51eb1ef5aad086439c51";
      size = 2329164;
    };

    powerpc64le-linux = {
      filename = "zls-powerpc64le-linux-0.15.1.tar.xz";
      shasum = "3b1a55f3e811426f0845f9ea3e16246ecc2896f0e602e87b2959166a5e42aa63";
      size = 3661480;
    };

    s390x-linux = {
      filename = "zls-s390x-linux-0.15.1.tar.xz";
      shasum = "0e95b1fab355f4931f16ab76a65515bde8f459114bc311cffb7944da8ce91be2";
      size = 4169564;
    };
  };

  meta-0_15_0 = {
    version = "0.15.0";
    date = "2025-08-24";

    aarch64-linux = {
      filename = "zls-aarch64-linux-0.15.0.tar.xz";
      shasum = "2d1c91382dbbd7a34c3bd87da506e3c2ce6e6582612c2b371f7f97b46c5557d4";
      size = 3545160;
    };

    arm64-darwin = {
      filename = "zls-aarch64-macos-0.15.0.tar.xz";
      shasum = "76c7a23190f67e67970024065f689c2c49b3c7b0fc16876fb24ef199fb05fc2a";
      size = 994744;
    };

    aarch64-mingw32 = {
      filename = "zls-aarch64-windows-0.15.0.zip";
      shasum = "5765e0fe96674577d4104e1e832205622390b8c1753305be78b9966f8d2d8468";
      size = 4237811;
    };

    armv7l-linux = {
      filename = "zls-arm-linux-0.15.0.tar.xz";
      shasum = "bcd86dc7d627c05ce4e1d212f2d88866af69a687b7cef5fbbf4f78d18e4f4d34";
      size = 3665280;
    };

    loongarch64-linux = {
      filename = "zls-loongarch64-linux-0.15.0.tar.xz";
      shasum = "ef13b90ccbf3ced990a648c99c4343230e80ff9444839afc94216c9cc2994d05";
      size = 3380940;
    };

    riscv64-linux = {
      filename = "zls-riscv64-linux-0.15.0.tar.xz";
      shasum = "4c3331846935ce442c51131e9e4a56bba1a4d28e149da211870b15a4b342baea";
      size = 4422732;
    };

    i686-linux = {
      filename = "zls-x86-linux-0.15.0.tar.xz";
      shasum = "a213e54be1e5aabf28a60fb55072f8d024a1b3d3a1ff2d6cf7132ba78db0892c";
      size = 3739404;
    };

    i686-mingw32 = {
      filename = "zls-x86-windows-0.15.0.zip";
      shasum = "e2662425bce7edebc133dd957c1bab9036e9c86455fc66dead416c3f5f1a93b9";
      size = 4506468;
    };

    x86_64-linux = {
      filename = "zls-x86_64-linux-0.15.0.tar.xz";
      shasum = "508bfe3fd637d2a02f07f3fc7da8900351f407116b03685c5dae26b4f01a30de";
      size = 3773176;
    };

    x86_64-darwin = {
      filename = "zls-x86_64-macos-0.15.0.tar.xz";
      shasum = "46c31838bfef5adcc7fee82428c3ec2b9abbfae38242639afea5f242ee133d93";
      size = 1165488;
    };

    x86_64-mingw32 = {
      filename = "zls-x86_64-windows-0.15.0.zip";
      shasum = "5f5e6861d55e96cc9e480cf15fbccafd2c44dfe193d8f3f9d54489a50cd73d2d";
      size = 4459264;
    };

    wasm32-wasi = {
      filename = "zls-wasm32-wasi-0.15.0.tar.xz";
      shasum = "17122b60af65e27c2f0db615bc847b5a43fc4f4af7da3caf15ae28e764fa2d75";
      size = 2317052;
    };

    powerpc64le-linux = {
      filename = "zls-powerpc64le-linux-0.15.0.tar.xz";
      shasum = "67540b2fa539176b8f7cd1493f3b9da2518bd5028feebbab619dc40841a9a25d";
      size = 3641264;
    };

    s390x-linux = {
      filename = "zls-s390x-linux-0.15.0.tar.xz";
      shasum = "da57b19901878b52e1c385e760af30b414df02a56bc4a17ddaae940dfcf90882";
      size = 4145096;
    };
  };

  meta-0_14_0 = {
    version = "0.14.0";
    date = "2025-03-06";

    aarch64-linux = {
      filename = "zls-linux-aarch64-0.14.0.tar.xz";
      shasum = "d85f4679af3961db149ead8a355eab4652c3e738eecaad69174cab5f1a1196cc";
      size = 3369008;
    };

    arm64-darwin = {
      filename = "zls-macos-aarch64-0.14.0.tar.xz";
      shasum = "dfb627e1f9603583678f552d8035a12dce878215c0a507b32d6f1b9d074d6c4d";
      size = 927968;
    };

    aarch64-mingw32 = {
      filename = "zls-windows-aarch64-0.14.0.zip";
      shasum = "7a6d649bafe5d09334b095829b461de1ee7f09278e068b28b90f1566df710a38";
      size = 4150974;
    };

    armv7l-linux = {
      filename = "zls-linux-armv7a-0.14.0.tar.xz";
      shasum = "34a41ddf6790959b220724957dedd2919f276298277f3e985dc68c7f9b47d3a0";
      size = 3535916;
    };

    loongarch64-linux = {
      filename = "zls-linux-loongarch64-0.14.0.tar.xz";
      shasum = "ce006e31084451a8cdb493965f93f8355485ec4693f54fcba377766ed61597f2";
      size = 3244668;
    };

    powerpc64le-linux = {
      filename = "zls-linux-powerpc64le-0.14.0.tar.xz";
      shasum = "c5d88b19017d8b9904a03cb088521f5bbd17171214b84bf2e712947f975b5b9f";
      size = 3548180;
    };

    riscv64-linux = {
      filename = "zls-linux-riscv64-0.14.0.tar.xz";
      shasum = "892915a4b06b0503681e45eb45d7bf67a7d7d48daeb73c4ffd0bfb0d59b27a4b";
      size = 4320460;
    };

    i686-linux = {
      filename = "zls-linux-x86-0.14.0.tar.xz";
      shasum = "79ca762b6cd5cffc165d473636fe0e1b225d2a4f75e5fed555261be4f046166b";
      size = 3604608;
    };

    i686-mingw32 = {
      filename = "zls-windows-x86-0.14.0.zip";
      shasum = "6c2d907830768f69a6296a6794da419597cb08d796243cf81e95452124649252";
      size = 4564797;
    };

    x86_64-linux = {
      filename = "zls-linux-x86_64-0.14.0.tar.xz";
      shasum = "661f8d402ba3dc9b04b6e9bc3026495be7b838d2f18d148db2bd98bd699c1360";
      size = 3567628;
    };

    x86_64-darwin = {
      filename = "zls-macos-x86_64-0.14.0.tar.xz";
      shasum = "baee69e4645deeccb42970b4a01f573592209dc1cf72e32893c59ca06af511dc";
      size = 1086696;
    };

    x86_64-mingw32 = {
      filename = "zls-windows-x86_64-0.14.0.zip";
      shasum = "10bb73102bab4d2fa9fd00ef48ad84ff2332b91e7fc449de751676367fe7dfd2";
      size = 4382699;
    };

    wasm32-wasi = {
      filename = "zls-wasi-wasm32-0.14.0.tar.xz";
      shasum = "cf9f77982c8d2549603c4361a4653817107974e29811ff7a857ef9230b6ad748";
      size = 2320208;
    };
  };

  meta-0_13_0 = {
    version = "0.13.0";
    date = "2024-06-09";

    x86_64-mingw32 = {
      filename = "zls-windows-x86_64-0.13.0.zip";
      shasum = "d87ed0834df3c30feae976843f0c6640acd31af1f31c0917907f7bfebae5bd14";
      size = 3773703;
    };

    x86_64-linux = {
      filename = "zls-linux-x86_64-0.13.0.tar.xz";
      shasum = "ec4c1b45caf88e2bcb9ebb16c670603cc596e4f621b96184dfbe837b39cd8410";
      size = 3292516;
    };

    x86_64-darwin = {
      filename = "zls-macos-x86_64-0.13.0.tar.xz";
      shasum = "4b63854d6b76810abd2563706e7d768efc7111e44dd8b371d49198e627697a13";
      size = 1047656;
    };

    i686-mingw32 = {
      filename = "zls-windows-x86-0.13.0.zip";
      shasum = "8d71f0fde1238082ee3b7fb5d9e361411183fad2d7a55a78b403ed7cd4fc2d13";
      size = 3876223;
    };

    i686-linux = {
      filename = "zls-linux-x86-0.13.0.tar.xz";
      shasum = "9b1632f53528ec29b214286a6056ba1b352737335311926c48317daf1f73f234";
      size = 3342824;
    };

    aarch64-linux = {
      filename = "zls-linux-aarch64-0.13.0.tar.xz";
      shasum = "8e258711168c2e3e7e81d6074663cfe291309b779928aaa4c66aed1affeba1aa";
      size = 3117620;
    };

    arm64-darwin = {
      filename = "zls-macos-aarch64-0.13.0.tar.xz";
      shasum = "9848514524f5e5d33997ac280b7d92388407209d4b8d4be3866dc3cf30ca6ca8";
      size = 929348;
    };

    wasm32-wasi = {
      filename = "zls-wasi-wasm32-0.13.0.tar.xz";
      shasum = "ed2af8a5c8661a3eeaa5d498db150c237fe721dd5f48f99ec14833c2b5208493";
      size = 2231904;
    };
  };

  meta-0_12_0 = {
    version = "0.12.0";
    date = "2024-06-08";

    aarch64-linux = {
      filename = "zls-linux-aarch64-0.12.0.tar.xz";
      shasum = "ea81ee5c64c8b39aaf23c26d641e263470738d76bee945db9f7207bad10f6d6f";
      size = 3058360;
    };

    i686-linux = {
      filename = "zls-linux-x86-0.12.0.tar.xz";
      shasum = "f9ed28d9eb12701b85aafd1956d0d2622086a11761a68561de26677f6410ae6c";
      size = 3307028;
    };

    x86_64-linux = {
      filename = "zls-linux-x86_64-0.12.0.tar.xz";
      shasum = "a1049798c9d3b14760f24de5c0a6b5a176abd404979828342b7319939563dfaa";
      size = 3238880;
    };

    arm64-darwin = {
      filename = "zls-macos-aarch64-0.12.0.tar.xz";
      shasum = "48892e8e75ebd8cbe1d82548e20094c4c9f7f1b81fdabe18b430f334d93dc76c";
      size = 912760;
    };

    x86_64-darwin = {
      filename = "zls-macos-x86_64-0.12.0.tar.xz";
      shasum = "6c6b24d2d57de6fcae8c44d8c484a359262b4a46339fe339a6fade433fc7c6b6";
      size = 1038668;
    };

    wasm32-wasi = {
      filename = "zls-wasi-wasm32-0.12.0.tar.xz";
      shasum = "82f9fa4394676c25e4b090253f4bcc811f2cc0186abef6e29e90d908af5c60a8";
      size = 2235168;
    };

    i686-mingw32 = {
      filename = "zls-windows-x86-0.12.0.zip";
      shasum = "38bf431c3d8eb484458c77a8b7517a44d1bdbc8e1b85d664f8e8f616d94a92c0";
      size = 3850972;
    };

    x86_64-mingw32 = {
      filename = "zls-windows-x86_64-0.12.0.zip";
      shasum = "3ff600660081c1867a83a800d22ad784849d1bee2e18bbe4495b95164e3de136";
      size = 3697303;
    };
  };

  meta-0_11_0 = {
    version = "0.11.0";
    date = "2024-06-08";

    aarch64-linux = {
      filename = "zls-linux-aarch64-0.11.0.tar.xz";
      shasum = "43184d2d324b27d2f18b72818676b367e6633264a0f4d74d1249b8a0824d1e1c";
      size = 2871712;
    };

    i686-linux = {
      filename = "zls-linux-x86-0.11.0.tar.xz";
      shasum = "580e8de3980778dc77aa0a77fb60efc0c71a17e12987f43379b326fc4c5dcf6c";
      size = 2954488;
    };

    x86_64-linux = {
      filename = "zls-linux-x86_64-0.11.0.tar.xz";
      shasum = "bd65d0cd79e83395b98035991b100821589b07ed8716fb2a44b1e234c9167f3f";
      size = 2965448;
    };

    arm64-darwin = {
      filename = "zls-macos-aarch64-0.11.0.tar.xz";
      shasum = "5152757727a958e6991b09fee4fb1b89c42b0e1c19f6b866e3567a83a126851c";
      size = 1605664;
    };

    x86_64-darwin = {
      filename = "zls-macos-x86_64-0.11.0.tar.xz";
      shasum = "8d3d83c8e1fc7a13d0c58624a9a0bdb289771c3714d01d7aace24277c95e70fb";
      size = 1746000;
    };

    wasm32-wasi = {
      filename = "zls-wasi-wasm32-0.11.0.tar.xz";
      shasum = "06e13738a34625fe36dd397dc095c8dd986ba49c214574d5a7d04aa0a5ca669d";
      size = 2799028;
    };

    i686-mingw32 = {
      filename = "zls-windows-x86-0.11.0.zip";
      shasum = "8fd720f60de35e59ea3ac465d83fe4c15fd002a3abd5c259abd1cabf30756626";
      size = 4530355;
    };

    x86_64-mingw32 = {
      filename = "zls-windows-x86_64-0.11.0.zip";
      shasum = "b14608a9541e89cbe8993ff22a6e3cf6248dd326cc5d42c4ee5469f2933e155b";
      size = 4186972;
    };
  };

  meta-0_10_0 = {
    version = "0.10.0";
    date = "2024-06-08";

    i686-linux = {
      filename = "zls-linux-x86-0.10.0.tar.xz";
      shasum = "dfc6f2d791b84ff7bd7bfe24e17bc1fed430b6f2db7d8a31735fa19c892334e4";
      size = 1142116;
    };

    x86_64-linux = {
      filename = "zls-linux-x86_64-0.10.0.tar.xz";
      shasum = "9a6cda8a9dc4b536f76439285541ad197eb30f67b0df47746411043c48091351";
      size = 1168192;
    };

    arm64-darwin = {
      filename = "zls-macos-aarch64-0.10.0.tar.xz";
      shasum = "543c9f7d8895ab12b8c0b860601513c54d354ffd558a439fed9152af74c65ce6";
      size = 378028;
    };

    x86_64-darwin = {
      filename = "zls-macos-x86_64-0.10.0.tar.xz";
      shasum = "bebd917db44e8fff8daf5aab9f06dbee183dad1ce351bc6ecb264ccae710d951";
      size = 486076;
    };

    i686-mingw32 = {
      filename = "zls-windows-x86-0.10.0.zip";
      shasum = "8b1e20ddf16419d956473830c450dbe6eb3f9022404b65a85bc0707437419405";
      size = 1645296;
    };

    x86_64-mingw32 = {
      filename = "zls-windows-x86_64-0.10.0.zip";
      shasum = "f9a29b8e5a743282112c53caa28de7f8534e4c83cf801011263202266fc5ff2e";
      size = 1582483;
    };
  };

  meta-0_9_0 = {
    version = "0.9.0";
    date = "2024-06-08";

    x86_64-linux = {
      filename = "zls-linux-x86_64-0.9.0.tar.xz";
      shasum = "0bb16e2e3a1c4dab22b1d6b25deeefd2212abcc2e88702a3f58705164703a7f8";
      size = 1145776;
    };

    i686-linux = {
      filename = "zls-linux-x86-0.9.0.tar.xz";
      shasum = "4596d0fcf236da331fa3afd9f282ac2492f22469f1b673465035b80850f4bd01";
      size = 1187788;
    };

    x86_64-darwin = {
      filename = "zls-macos-x86_64-0.9.0.tar.xz";
      shasum = "d8f2e8deda1751d7d46979b686784ebd5c843a9ba8f0bce69424351c4bfbea5f";
      size = 417592;
    };

    i686-mingw32 = {
      filename = "zls-windows-x86-0.9.0.zip";
      shasum = "30cdf11c1c4cfe8ec260596dbf80ec498740ecd7fce6a025006176e21a90cd52";
      size = 1648827;
    };

    x86_64-mingw32 = {
      filename = "zls-windows-x86_64-0.9.0.zip";
      shasum = "0a99b39124c536fc277208b71c1ddb82a8ba29aa9de1df5a4e824d633420f62e";
      size = 1627474;
    };
  };
in
{
  latest = bin meta-0_16_0;
  "0_16_0" = bin meta-0_16_0;
  "0_15_1" = bin meta-0_15_1;
  "0_15_0" = bin meta-0_15_0;
  "0_14_0" = bin meta-0_14_0;
  "0_13_0" = bin meta-0_13_0;
  "0_12_0" = bin meta-0_12_0;
  "0_11_0" = bin meta-0_11_0;
  "0_10_0" = bin meta-0_10_0;
  "0_9_0" = bin meta-0_9_0;
  # aliases
  "0_15_2" = bin meta-0_15_1;
  "0_14_1" = bin meta-0_14_0;
  "0_12_1" = bin meta-0_12_0;
  "0_10_1" = bin meta-0_10_0;
  "0_9_1" = bin meta-0_9_0;
}
