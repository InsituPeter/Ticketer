import { AppError } from './AppError'

export class ForbiddenError extends AppError {
  constructor(message = 'Insufficient permissions') {
    super('INSUFFICIENT_PERMISSIONS', message, 403)
    this.name = 'ForbiddenError'
  }
}
