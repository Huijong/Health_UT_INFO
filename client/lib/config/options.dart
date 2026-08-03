import 'package:flutter/material.dart';

/// Galaxy Watch 드롭다운 선택지 (2단계 전용)
const List<String> kWatchOptions = [
  'Galaxy Watch 9 Small',
  'Galaxy Watch 9 Large',
  'Galaxy Watch Ultra2',
  'Galaxy Watch 9 FE',
  'Galaxy Watch 8 small',
  'Galaxy Watch 8 large',
  'Galaxy Watch 8 Classic',
  'Galaxy Watch 8 FE',
  'Galaxy Watch 7 Small',
  'Galaxy Watch 7 Large',
  'Galaxy Watch Ultra',
  'Galaxy Watch 7 FE',
  '직접입력',
];

/// 워치 스트랩 선택지 (3단계 전용)
const List<Map<String, String>> kStrapOptions = [
  {
    'name': '기본 스트랩',
    'url': ''
  },
  {
    'name': '갤럭시 워치8 시리즈 하이브리드 밴드 (S/M/L)',
    'url': 'https://www.samsung.com/sec/mobile-accessories/hybrid-band-for-galaxy-watch-8/ET-SLL50LWEGKR/'
  },
  {
    'name': '갤럭시 워치8 시리즈 스포츠 밴드 (슬림, S/M)',
    'url': 'https://www.samsung.com/sec/mobile-accessories/sports-band-slim-sm-for-galaxy-watch-8/ET-SNL32SNEGKR/'
  },
  {
    'name': '갤럭시 워치8 시리즈 스포츠 밴드 (와이드, M/L)',
    'url': 'https://www.samsung.com/sec/mobile-accessories/sports-band-wide-ml-for-galaxy-watch-8/ET-SNL33LBEGKR/'
  },
  {
    'name': '갤럭시 워치8 시리즈 애슬레저 밴드 (슬림, S/M)',
    'url': 'https://www.samsung.com/sec/mobile-accessories/athleisure-band-slim-sm-for-galaxy-watch-8/ET-SOL32SNEGKR/'
  },
  {
    'name': '갤럭시 워치8 시리즈 애슬레저 밴드 (와이드, M/L)',
    'url': 'https://www.samsung.com/sec/mobile-accessories/athleisure-band-wide-ml-for-galaxy-watch-8/ET-SOL33LNEGKR/'
  },
  {
    'name': '갤럭시 워치8 시리즈 패브릭 밴드 (슬림, S/M)',
    'url': 'https://www.samsung.com/sec/mobile-accessories/fabric-band-slim-sm-for-galaxy-watch-8/ET-SVL32SNEGKR/'
  },
  {
    'name': '갤럭시 워치8 시리즈 패브릭 밴드 (와이드, M/L)',
    'url': 'https://www.samsung.com/sec/mobile-accessories/fabric-band-wide-ml-for-galaxy-watch-8/ET-SVL33LNEGKR/'
  },
  {
    'name': '갤럭시 워치8 시리즈 프리미엄 레더 밴드',
    'url': 'https://www.samsung.com/sec/mobile-accessories/premium-leather-band-for-galaxy-watch-8/GP-TYL505AMBBK/'
  },
  {
    'name': '갤럭시 워치8 시리즈 슬림 레더 밴드',
    'url': 'https://www.samsung.com/sec/mobile-accessories/slim-leather-band-for-galaxy-watch-8/GP-TYL325AMBBK/'
  },
  {
    'name': '갤럭시 워치8 시리즈 나토 밴드',
    'url': 'https://www.samsung.com/sec/mobile-accessories/nato-band-galaxy-watch-8/GP-TYL335AMBJK/'
  },
  {
    'name': '갤럭시 워치8 시리즈 벨크로 밴드',
    'url': 'https://www.samsung.com/sec/mobile-accessories/velcro-band-for-galaxy-watch-8/GP-TYL335HICNK/'
  },
  {
    'name': '갤럭시 워치 울트라 마린 밴드',
    'url': 'https://www.samsung.com/sec/mobile-accessories/marine-band-galaxy-watch-ultra/ET-SNL70MNEGKR/'
  },
  {
    'name': '갤럭시 워치 울트라 트레일 밴드',
    'url': 'https://www.samsung.com/sec/mobile-accessories/trail-band-galaxy-watch-ultra/ET-SVL70MNEGKR/'
  },
  {
    'name': '갤럭시 워치 울트라 픽폼 밴드',
    'url': 'https://www.samsung.com/sec/mobile-accessories/peakform-band-for-galaxy-watch-ultra/ET-SBL70MBEGKR/'
  },
  {
    'name': '갤럭시 워치7 스포츠 밴드 (와이드, M/L)',
    'url': 'https://www.samsung.com/sec/mobile-accessories/sports-band-wide-ml-for-galaxy-watch-7/ET-SNL31LKEGKR/'
  },
  {
    'name': '갤럭시 워치7 스포츠 밴드 (슬림, S/M)',
    'url': 'https://www.samsung.com/sec/mobile-accessories/sports-band-slim-sm-for-galaxy-watch-7/ET-SNL30SOEGKR/'
  },
  {
    'name': '갤럭시 워치7 애슬레저 밴드 (와이드, M/L)',
    'url': 'https://www.samsung.com/sec/mobile-accessories/athleisure-band-slim-sm-for-galaxy-watch-7/ET-SOL31LLEGKR/'
  },
  {
    'name': '갤럭시 워치7 애슬레저 밴드 (슬림, S/M)',
    'url': 'https://www.samsung.com/sec/mobile-accessories/athleisure-band-wide-ml-for-galaxy-watch-7/ET-SOL30SPEGKR/'
  },
  {
    'name': '갤럭시 워치7 패브릭 밴드 (와이드, M/L)',
    'url': 'https://www.samsung.com/sec/mobile-accessories/fabric-band-wide-ml-for-galaxy-watch-7/ET-SVL31LWEGKR/'
  },
  {
    'name': '갤럭시 워치7 패브릭 밴드 (슬림, S/M)',
    'url': 'https://www.samsung.com/sec/mobile-accessories/fabric-band-slim-sm-for-galaxy-watch-7/ET-SVL30SWEGKR/'
  },
  {
    'name': '직접입력',
    'url': ''
  }
];
