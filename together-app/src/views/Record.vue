<template>
    <v-card class="mx-auto mb-3 pb-3" max-width="368" v-for="(record,i) in records" @click="router.push({name:'View Activity',params:{id:record.activity}})">
        <v-card-item :title="activities[i].name">
            <template v-slot:subtitle>
                <v-icon icon="mdi-map-marker" size="18" class="me-1 pb-1"></v-icon>
                {{ activities[i].location }}
            </template>
        </v-card-item>

        <v-card-text class="py-0">
            <v-row align="center" no-gutters>
                <v-col cols="6">
                    {{ activities[i].brief_description}}
                </v-col>

                <v-col cols="6" :class="{'text-right':true,'text-green':records[i].state=='done'}" style="text-transform:uppercase">
                    {{ record.state }}
                </v-col>
            </v-row>
        </v-card-text>
    </v-card>
</template>

<script lang="ts" setup>
import axios from 'axios';
import {UID} from '@/types'
import { useRouter } from 'vue-router'
const router=useRouter()
const records=await(await axios.get(`/api/v1/record/find?user=${UID}`)).data
const activities = Array()

for (const record of records){
    activities.push(await((await axios.get(`/api/v1/activity/${record.activity}`)).data))
}
</script>
