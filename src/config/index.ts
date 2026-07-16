import 'dotenv/config'
import {z} from 'zod'

const envSchema = z.object({
    PORT:z.coerce.number().default(8810),
    NODE_ENV:z.enum(['development', 'production', 'test']).default('development'),
    DATABASE_URL:z.string(),
    REDIS_URL:z.string(),
    JWT_SECRET:z.string().min(1),
    PAYSTACK_SECRET_KEY:z.string().min(1),
     POSTMARK_SERVER_TOKEN: z.string().min(1),




})

const parsed= envSchema.safeParse(process.env)
if(!parsed.success){
    const message = parsed.error.issues
                    .map((e)=>`${e.path.join('.')}:${e.message}`)
                    .join(',')
    console.error(message)  
    process.exit(1)       
}


export const config= parsed.data