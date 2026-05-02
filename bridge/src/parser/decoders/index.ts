import { deltaPro3Decoder } from './deltaPro3Decoder.js';
import { river3Decoder } from './river3Decoder.js';
import type { DecoderContext } from './types.js';

const DECODERS = [deltaPro3Decoder, river3Decoder];

export function decodeModelTelemetry(
  params: Record<string, unknown>,
  ctx: DecoderContext,
): Record<string, unknown> {
  for (const decoder of DECODERS) {
    if (decoder.supports(ctx)) {
      return decoder.decode(params, ctx).params;
    }
  }
  return params;
}

