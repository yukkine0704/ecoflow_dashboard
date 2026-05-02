export interface DecoderContext {
  model: string | null | undefined;
  envelope: { cmdFunc: number; cmdId: number } | null;
}

export interface ModelDecoderOutput {
  params: Record<string, unknown>;
}

export interface ModelDecoder {
  supports(ctx: DecoderContext): boolean;
  decode(params: Record<string, unknown>, ctx: DecoderContext): ModelDecoderOutput;
}

