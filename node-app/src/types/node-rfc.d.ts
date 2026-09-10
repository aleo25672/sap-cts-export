declare module "node-rfc" {
  export class Client {
    constructor(params: Record<string, string>);
    open(): Promise<void>;
    close(): Promise<void>;
    call(fm: string, params: Record<string, unknown>): Promise<Record<string, unknown>>;
  }
}
