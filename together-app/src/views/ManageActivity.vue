<template>
    <activity-card v-model="activity" />
    <v-list>
        <v-list-item v-for="volunteer in volunteers" :title="volunteer.user.realname" :subtitle="volunteer.user.classname"
            class="mb-4">
            <template v-slot:prepend>
                <v-avatar color="grey-lighten-1">
                    <v-icon color="white">mdi-folder</v-icon>
                </v-avatar>


            </template>
            <template v-slot:append>
                <v-btn color="green" :text="volunteer.record.state=='todo'?'Mark as Done':'Done'" :disabled="!(volunteer.record.state=='todo')" @click="mark_done(volunteer.record.id);volunteer.record.state='done'"></v-btn>
            </template>
        </v-list-item>
    </v-list>
</template>

<script lang="ts" setup>
import { Activity } from '@/types'
import { Ref, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import ActivityCard from '@/components/ActivityCard.vue'
import axios from 'axios'

const route = useRoute()
const router = useRouter()
const id = route.params.id


const activity: Ref<Activity> = ref(await (await axios.get(`/api/v1/activity/${id}`)).data)
const volunteers = ref(Array())
for (const volunteer of activity.value.volunteers) {
    let user = await (await axios.get(`/api/v1/user/${volunteer}`)).data
    /// TODO : allow user to join activity again after they exits the activity.
    let record = await (await axios.get(`/api/v1/record/find?user=${volunteer}&activity=${id}`)).data[0]

    volunteers.value.push({user,record})

}

async function mark_done(record_id:string){
    await axios.post(`/api/v1/record/${record_id}/done`)

}

</script>