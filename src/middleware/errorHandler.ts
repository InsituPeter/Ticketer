import { Request, Response, NextFunction } from 'express'
import { AppError, ValidationError } from '../errors'

export function errorHandler(
  err: Error,
  req: Request,
  res: Response,
  next: NextFunction,
): void {
  if (err instanceof AppError) {
    const body: Record<string, unknown> = {
      error: {
        code: err.code,
        message: err.message,
      },
    }

    if (err instanceof ValidationError) {
      body.error.details = err.details
    }

    res.status(err.statusCode).json(body)
    return
  }

  console.error('Unhandled error:', err)

  res.status(500).json({
    error: {
      code: 'INTERNAL_SERVER_ERROR',
      message: 'An unexpected error occurred',
    },
  })
}
