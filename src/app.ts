import express from 'express'
import helmet from 'helmet'
import cors from 'cors'
import {errorHandler} from './middleware/errorHandler'

export function createApp(){
    const app=express()

app.use(helmet())
app.use(cors())
app.use(express.json())



app.get('/health',(req, res)=>{
    res.json({status:'ok', timestamp: new Date().toISOString()})
})

app.use(errorHandler)
return app
}