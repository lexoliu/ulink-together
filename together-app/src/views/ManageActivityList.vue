<template>
    <activity-list v-model="activities" @click="click"/>

    <VLayoutItem model-value position="bottom" class="text-end" size="auto" style="margin-bottom:50px">
        <div class="ma-4">
            <VBtn icon="mdi-plus" size="large" color="green" elevation="8"
                @click="router.push({ name: 'Create Activity' })" />
        </div>
    </VLayoutItem>
</template>

<script lang="ts" setup>
import { useRouter } from 'vue-router'
import axios from 'axios'
import ActivityList from '@/components/ActivityList.vue'
import { Activity } from '@/types'
import VueCookies from 'vue-cookies'
const router = useRouter()
const uid = (VueCookies as any).get("uid")
interface Item {
    icon: string,
    route_name: string,
}


let activities: Activity[] = await (await axios.get(`/api/v1/activity?user=${uid}`)).data;

function click(activity:Activity){
    router.push({ name: 'Manage Activity', params: { id: activity.id } })

}


</script>