/* Augment Express Request with `user?: { id: string }` */
import "express";
declare global {
  namespace Express {
    interface UserPayload {
      id: string;
    }
    interface Request {
      user?: UserPayload;
    }
  }
}
export {};
