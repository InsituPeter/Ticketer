import {createApp} from './app'
import {config} from './config'

const app = createApp()
const server= app.listen(config.PORT, ()=>{
        console.log(`Server running on port ${config.PORT}`)
})

const shutdown=()=>{
    console.log('Shutting down...')
    server.close(()=>{
        console.log('Server closed')
        process.exit(0)
    })

   setTimeout(() => {
    console.error('Forced shutdown')
    process.exit(1)
  }, 10_000)
 
}


process.on('SIGTERM', shutdown)
process.on('SIGINT', shutdown)