import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ecoflow_dashboard/core/ecoflow/ecoflow_bootstrap_service.dart';
import 'package:ecoflow_dashboard/core/ecoflow/ecoflow_models.dart';

void main() {
  group('EcoFlowBootstrapService', () {
    test('uses only iot-open endpoints in bootstrap flow', () async {
      final calledPaths = <String>[];
      final dio = Dio(BaseOptions(baseUrl: 'https://api.ecoflow.com'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            calledPaths.add(options.path);
            if (options.path == '/iot-open/sign/certification') {
              handler.resolve(
                Response<dynamic>(
                  requestOptions: options,
                  statusCode: 200,
                  data: <String, dynamic>{
                    'code': '0',
                    'message': 'Success',
                    'data': <String, dynamic>{
                      'certificateAccount': 'open-test-account',
                      'certificatePassword': 'pwd',
                      'url': 'mqtt.ecoflow.com',
                      'port': '8883',
                      'protocol': 'mqtts',
                    },
                  },
                ),
              );
              return;
            }
            if (options.path == '/iot-open/sign/device/list') {
              handler.resolve(
                Response<dynamic>(
                  requestOptions: options,
                  statusCode: 200,
                  data: <String, dynamic>{
                    'code': '0',
                    'message': 'Success',
                    'data': <Map<String, dynamic>>[
                      <String, dynamic>{
                        'sn': 'SN123',
                        'deviceName': 'RIVER 3',
                        'online': 1,
                      },
                    ],
                  },
                ),
              );
              return;
            }
            handler.reject(
              DioException.badResponse(
                statusCode: 404,
                requestOptions: options,
                response: Response<dynamic>(
                  requestOptions: options,
                  statusCode: 404,
                ),
              ),
            );
          },
        ),
      );

      final service = EcoFlowBootstrapService(
        baseUrl: 'https://api.ecoflow.com',
        dio: dio,
      );
      final bundle = await service.bootstrap(
        const EcoFlowCredentials(accessKey: 'ak', secretKey: 'sk'),
      );

      expect(
        calledPaths,
        <String>[
          '/iot-open/sign/certification',
          '/iot-open/sign/device/list',
        ],
      );
      expect(bundle.mqttEndpointUsed, '/iot-open/sign/certification');
      expect(bundle.deviceEndpointUsed, '/iot-open/sign/device/list');
      expect(bundle.certificateAccount, 'open-test-account');
      expect(bundle.mqtt.host, 'mqtt.ecoflow.com');
      expect(bundle.mqtt.port, 8883);
      expect(bundle.mqtt.useTls, isTrue);
      expect(bundle.device.sn, 'SN123');
    });

    test('publishes canonical endpoint lists', () {
      expect(
        EcoFlowBootstrapService.mqttCertificationEndpoints,
        <String>['/iot-open/sign/certification'],
      );
      expect(
        EcoFlowBootstrapService.deviceListEndpoints,
        <String>['/iot-open/sign/device/list'],
      );
    });
  });
}
