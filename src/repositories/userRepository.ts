import {prisma} from '../lib/prisma'

export class UserRepository{
    async create(data:Prisma.UserCreateInput){
        return prisma.user.create({data})
    }
    async findByEmail(email:String){
        return prisma.user.findUnique(
            {where:{email}}
        
        )

    }
    async findById(id:string){
        return prisma.user.findUnique({where:{id}})
    }
}