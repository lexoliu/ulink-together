<template>
  <activity-list v-model="activities" @click="click" />
</template>

<script lang="ts" setup>
import ActivityList from '@/components/ActivityList.vue';
import { Activity } from '@/types'
import axios from 'axios'
import { useRouter } from 'vue-router';
const router = useRouter()

let activities: Activity[] = await (await axios.get("/api/v1/activity")).data;


function click(activity: Activity) {
  router.push({ name: 'View Activity', params: { id: activity.id } })
}

</script>
