import VueCookies from "vue-cookies"

export interface Activity {
    id: string,
    title: string,
    date?: Date,
    description: string,
    location: string,
    volunteer_num: number,
    max_volunteer_num?: number,
    promoter_name: string,
    duration: number,// minutes
    volunteers:string[],
}


export const UID = (VueCookies as any).get("uid")