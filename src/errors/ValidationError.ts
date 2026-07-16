import { AppError } from './AppError'

export class ValidationError extends AppError {


  constructor(
    message = 'Request validation failed',
     details: Array<{ path: string; message: string }> = []
  ) {
    super('VALIDATION_ERROR', message, 422)
    this.details = details
  }
}
