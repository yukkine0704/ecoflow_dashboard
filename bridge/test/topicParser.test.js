import assert from 'node:assert/strict';
import test from 'node:test';
import { parseHaTopic } from '../src/core/topicParser.js';
test('parse status topic', () => {
    const parsed = parseHaTopic('iob_ef/HW51TEST/info/status', 'iob_ef');
    assert.deepEqual(parsed, { kind: 'status', deviceId: 'HW51TEST' });
});
test('parse metric topic', () => {
    const parsed = parseHaTopic('iob_ef/HW51TEST_pd/soc', 'iob_ef');
    assert.deepEqual(parsed, {
        kind: 'metric',
        deviceId: 'HW51TEST',
        channel: 'pd',
        state: 'soc',
    });
});
test('ignore foreign topic', () => {
    const parsed = parseHaTopic('other/HW51TEST_pd/soc', 'iob_ef');
    assert.equal(parsed, null);
});
