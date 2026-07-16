
export class AppError extends Error{
       public readonly errorCode: string
        public readonly statusCode: number
        public readonly isOperational: boolean
        public readonly timestamp: string
        public readonly details?: Record<string, unknown>

    constructor(
       message:string,
       errorCode:string,
       statusCode:number,
       isOperational:boolean,
       details?:Record<string, unknown>
    )

{
     super(message)
    this.name =this.constructor.name
    this.errorCode =errorCode
    this.statusCode=statusCode
    this.isOperational=isOperational
    this.timestamp= new Date().toISOString()
    this.details = details

       Object.setPrototypeOf(this, new.target.prototype)
    Error.captureStackTrace(this, this.constructor)
}
   


}