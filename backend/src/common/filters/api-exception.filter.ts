import {
  ExceptionFilter, Catch, ArgumentsHost, HttpException, HttpStatus,
} from "@nestjs/common";
import { Response, Request } from "express";
import { randomUUID } from "crypto";

@Catch()
export class ApiExceptionFilter implements ExceptionFilter {
  catch(exception: unknown, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const res = ctx.getResponse<Response>();
    const req = ctx.getRequest<Request>();
    const requestId = (req.headers["x-request-id"] as string) || randomUUID();

    let status = HttpStatus.INTERNAL_SERVER_ERROR;
    let message = "Internal server error";
    let code = "INTERNAL_ERROR";

    if (exception instanceof HttpException) {
      status = exception.getStatus();
      const body = exception.getResponse();
      if (typeof body === "string") {
        message = body;
      } else if (body && typeof body === "object") {
        const o = body as Record<string, unknown>;
        if (Array.isArray(o.message)) {
          message = (o.message as string[]).join("; ");
          code = "VALIDATION_ERROR";
        } else if (typeof o.message === "string") {
          message = o.message;
        }
      }
      if (status === 401) code = "UNAUTHENTICATED";
      else if (status === 403) code = "FORBIDDEN";
      else if (status === 404) code = "RESOURCE_NOT_FOUND";
      else if (status === 409) code = "CONFLICT";
      else if (status === 429) code = "RATE_LIMITED";
      else if (status === 400 && code === "INTERNAL_ERROR") code = "VALIDATION_ERROR";
    }

    res.status(status).json({
      success: false,
      data: null,
      error: { statusCode: status, code, message, requestId },
    });
  }
}