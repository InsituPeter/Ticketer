import { Request, Response, NextFunction } from 'express'
import { ZodTypeAny } from 'zod'
import { ValidationError } from '../errors'

type ValidationTarget = 'body' | 'query' | 'params'

export function validate<T extends ZodTypeAny>(
  schema: T,
  target: ValidationTarget = 'body',
) {
  return (req: Request, res: Response, next: NextFunction): void => {
    const result = schema.safeParse(req[target])

    if (!result.success) {
      const details = result.error.issues.map((issue) => ({
        path: issue.path.join('.'),
        message: issue.message,
      }))

      throw new ValidationError('Request validation failed', details)
    }

    next()
  }
}
