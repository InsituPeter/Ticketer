import { AppError } from './AppError'

export class AuthorizationError extends AppError {
  constructor(message = 'Authentication required') {
    super('UNAUTHORIZED', message, 401)
    this.name = 'AuthorizationError'
  }
}
