import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({super.key});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final MapController _mapController = MapController();
  LatLng _centerLatLng = const LatLng(37.5665, 126.9780); // 서울 중심
  String _address = '위치 정보를 가져오는 중...';
  bool _isResolving = false;
  bool _isLoadingGps = true;

  @override
  void initState() {
    super.initState();
    _moveToCurrentPosition();
  }

  Future<void> _moveToCurrentPosition() async {
    setState(() {
      _isLoadingGps = true;
    });

    try {
      // 1. 위치 권한 확인 및 요청
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _setAddressError('위치 권한이 거부되었습니다.');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _setAddressError('위치 권한이 설정에서 거부되었습니다.');
        return;
      }

      // 2. 현재 GPS 좌표 가져오기
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final newLatLng = LatLng(position.latitude, position.longitude);
      setState(() {
        _centerLatLng = newLatLng;
      });

      _mapController.move(newLatLng, 16.0);
      _reverseGeocode(newLatLng);
    } catch (e) {
      _setAddressError('GPS 위치를 가져올 수 없습니다.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingGps = false;
        });
      }
    }
  }

  void _setAddressError(String error) {
    if (mounted) {
      setState(() {
        _address = error;
        _isLoadingGps = false;
      });
    }
  }

  Future<void> _reverseGeocode(LatLng latLng) async {
    if (_isResolving) return;
    setState(() {
      _isResolving = true;
      _address = '주소를 변환하는 중...';
    });

    try {
      // geocoding 패키지로 한국어 주소로 역지오코딩 수행
      List<Placemark> placemarks = await placemarkFromCoordinates(
        latLng.latitude,
        latLng.longitude,
      );

      if (placemarks.isNotEmpty) {
        final pm = placemarks.first;
        
        // 주소 형식 조립
        final String city = pm.administrativeArea ?? ''; // 서울특별시, 경기도 등
        final String subCity = pm.locality ?? ''; // 성남시 등
        final String district = pm.subLocality ?? ''; // 분당구 등
        final String street = pm.thoroughfare ?? ''; // 정자동 등
        final String subStreet = pm.subThoroughfare ?? ''; // 번지 번호 등
        final String name = pm.name ?? ''; // 상세 장소명/건물번호 등

        String formattedAddress = '';
        if (city.isNotEmpty) formattedAddress += '$city ';
        if (subCity.isNotEmpty && subCity != city) formattedAddress += '$subCity ';
        if (district.isNotEmpty) formattedAddress += '$district ';
        if (street.isNotEmpty) formattedAddress += '$street ';
        if (subStreet.isNotEmpty && subStreet != street && !name.contains(subStreet)) {
          formattedAddress += '$subStreet ';
        } else if (name.isNotEmpty && name != street) {
          formattedAddress += name;
        }

        formattedAddress = formattedAddress.trim();
        if (formattedAddress.isEmpty) {
          formattedAddress = '지정된 주소 없음 (${latLng.latitude.toStringAsFixed(4)}, ${latLng.longitude.toStringAsFixed(4)})';
        }

        setState(() {
          _address = formattedAddress;
        });
      } else {
        setState(() {
          _address = '주소 정보가 없습니다.';
        });
      }
    } catch (e) {
      setState(() {
        _address = '주소 변환 실패 (네트워크 연결 확인)';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isResolving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0C0F0F),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF2E5BFF),
          secondary: Color(0xFF3DFFC1),
          surface: Color(0xFF1E2020),
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF1E2020),
          title: const Text('운동 장소 선택', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.my_location_rounded, color: Color(0xFF3DFFC1)),
              onPressed: _moveToCurrentPosition,
              tooltip: '현재 위치로 이동',
            )
          ],
        ),
        body: Stack(
          children: [
            // 1. 오픈스트리트맵 지도 영역
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _centerLatLng,
                initialZoom: 16.0,
                onPositionChanged: (position, hasGesture) {
                  if (hasGesture && position.center != null) {
                    setState(() {
                      _centerLatLng = position.center!;
                    });
                  }
                },
                onMapEvent: (event) {
                  // 지도 드래그가 끝났을 때 역지오코딩 수행
                  if (event is MapEventMoveEnd) {
                    _reverseGeocode(_centerLatLng);
                  }
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.healthport',
                ),
              ],
            ),

            // 2. 화면 중앙 핀 표시 (고정식 마커)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 35), // 핀 하단 끝점을 센터에 위치시킴
                child: Icon(
                  Icons.location_pin,
                  color: Colors.redAccent,
                  size: 44,
                  shadows: [
                    Shadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 4,
                      offset: const Offset(0, 3),
                    )
                  ],
                ),
              ),
            ),

            // 3. 현재 위치 로딩 스피너
            if (_isLoadingGps)
              Container(
                color: Colors.black38,
                child: const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3DFFC1)),
                  ),
                ),
              ),

            // 4. 하단 주소 상세 표시 및 결정 카드
            Positioned(
              left: 20,
              right: 20,
              bottom: 24,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2020).withOpacity(0.95),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    )
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '선택된 운동 장소 주소',
                      style: TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.location_on_rounded, color: Color(0xFF3DFFC1), size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _address,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: (_isResolving || _isLoadingGps || _address.contains('가져오는 중') || _address.contains('변환하는 중'))
                            ? null
                            : () {
                                Navigator.pop(context, _address);
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3DFFC1),
                          foregroundColor: const Color(0xFF0C0F0F),
                          disabledBackgroundColor: Colors.white.withOpacity(0.12),
                          disabledForegroundColor: Colors.white24,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          '이 위치로 선택',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
