import 'package:flutter_test/flutter_test.dart';

import 'package:ecoflow_dashboard/core/ecoflow/ecoflow_models.dart';

void main() {
  group('EcoFlowBootstrapBundle topics', () {
    test('builds quota/status/set_reply topics by device sn', () {
      const bundle = EcoFlowBootstrapBundle(
        mqtt: EcoFlowMqttCertification(
          host: 'mqtt.ecoflow.com',
          port: 8883,
          username: 'open-abc',
          password: 'pwd',
          protocol: 'mqtts',
          useTls: true,
          certificateAccount: 'open-abc',
        ),
        device: EcoFlowDeviceIdentity(sn: 'SN1'),
        devices: <EcoFlowDeviceIdentity>[EcoFlowDeviceIdentity(sn: 'SN1')],
        certificateAccount: 'open-abc',
        mqttEndpointUsed: '/iot-open/sign/certification',
        deviceEndpointUsed: '/iot-open/sign/device/list',
      );

      expect(bundle.quotaTopic, '/open/open-abc/SN1/quota');
      expect(bundle.statusTopic, '/open/open-abc/SN1/status');
      expect(bundle.setReplyTopic, '/open/open-abc/SN1/set_reply');
      expect(
        bundle.topicsForDeviceSn('SN2'),
        <String>[
          '/open/open-abc/SN2/quota',
          '/open/open-abc/SN2/status',
          '/open/open-abc/SN2/set_reply',
        ],
      );
    });
  });
}
