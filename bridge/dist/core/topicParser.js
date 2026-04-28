export function parseHaTopic(topic, haRootTopic) {
    const normalizedRoot = haRootTopic.replace(/\/+$/, '');
    if (!topic.startsWith(`${normalizedRoot}/`)) {
        return null;
    }
    const tail = topic.slice(normalizedRoot.length + 1);
    const parts = tail.split('/').filter(Boolean);
    if (parts.length === 3 && parts[1] === 'info' && parts[2] === 'status') {
        return { kind: 'status', deviceId: parts[0] };
    }
    if (parts.length === 2) {
        const [deviceChannel, state] = parts;
        const split = deviceChannel.split('_');
        if (split.length < 2) {
            return null;
        }
        const deviceId = split.shift();
        if (!deviceId) {
            return null;
        }
        const channel = split.join('_');
        return {
            kind: 'metric',
            deviceId,
            channel,
            state,
        };
    }
    return null;
}
