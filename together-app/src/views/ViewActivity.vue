<template>
    <v-card class="mx-auto mb-3 pa-2" max-width="600">

        <v-card-item :title="activity.title">
            <template v-slot:subtitle>
                <v-icon icon="mdi-map-marker" size="18" class="me-1 pb-1"></v-icon>
                {{ activity.location }}
            </template>
        </v-card-item>

        <v-card-text class="py-0">
            <v-row align="center" no-gutters>
                <v-col cols="6">
                    {{ activity.description }}
                </v-col>

                <v-col cols="6" class="text-right">
                    <v-icon color="error" icon="mdi-weather-hurricane" size="88"></v-icon>
                </v-col>
            </v-row>
        </v-card-text>

        <div class="d-flex py-3 justify-space-between">
            <v-list-item density="compact" prepend-icon="mdi-account-group">
                <v-list-item-subtitle>{{ activity.volunteer_num }}/{{ activity.max_volunteer_num || "?"
                }}</v-list-item-subtitle>
            </v-list-item>

            <v-list-item density="compact">
                <div class="text-none text-subtitle-2" variant="text">Set by {{ activity.promoter_name }}</div>
            </v-list-item>
        </div>

        <v-progress-linear
            :model-value="(activity.volunteer_num / (activity.max_volunteer_num || 20)) * 100"></v-progress-linear>
        <div>
            <v-btn color="green" :text="joined() ? 'Joined' : 'Join'" class="ma-5 float-right" @click="join"
                :disabled="joined()"></v-btn>

        </div>
        <v-divider style="margin-top:80px" class="mb-2"></v-divider>
        <v-card-item title="Comment"></v-card-item>
        <v-list class="pb-7">

            <v-list-item v-for="comment in comments" :title="comment.author_name" :subtitle="comment.content" class="pb-4">
                <template v-slot:prepend>
                    <v-avatar color="grey-lighten-1">
                        <v-icon color="white">mdi-account</v-icon>
                    </v-avatar>
                </template>
            </v-list-item>
            <v-list-item>
                <v-form @submit.prevent="post_comment">
                    <v-text-field label="Comment" class="mt-5" variant="underlined" v-model="comment"></v-text-field>
                </v-form>

            </v-list-item>

        </v-list>


    </v-card>
</template>
  
<script lang="ts" setup>
import axios from 'axios'
import { Ref, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import VueCookies from 'vue-cookies'

import { Activity } from '@/types'

const route = useRoute()
const id = route.params.id
const comment = ref("")
const uid = (VueCookies as any).get("uid")
let activity: Ref<Activity> = ref(await (await axios.get(`/api/v1/activity/${id}`)).data);
const router = useRouter()



interface Comment {
    author_name: string,
    author_id: string,
    content: string,
    date: Date
}


const comments: Ref<Comment[]> = ref([])

const activity_id = route.params.id;

async function join() {
    await axios.post(`/api/v1/activity/${activity_id}/join`)
    activity.value.volunteers.push(uid)
}

async function pull_comment() {
    comments.value = await (await axios.get(`/api/v1/activity/${activity_id}/comment`)).data
}

async function post_comment() {
    await axios.post(`/api/v1/activity/${activity_id}/comment`, comment.value);
    comments.value.push({ author_name: "Me", author_id: "", content: comment.value, date: new Date() })
    comment.value = ""
}

function joined(): boolean {
    return activity.value.volunteers.includes(uid)
}

await pull_comment()

</script>
  