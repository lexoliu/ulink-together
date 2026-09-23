<template>
    <v-form @submit.prevent="submit">
        <v-text-field label="Activity name" prepend-inner-icon="mdi-seesaw" v-model="name" :rules="[rules.required]" />
        <v-text-field label="Maximum number of volunteer" prepend-inner-icon="mdi-account-group" type="number"
            v-model="max_volunteer" />

            <v-text-field label="Location" prepend-inner-icon="mdi-map-marker" v-model="location" :rules="[rules.required]" />

        <v-text-field label="Activity duration" type="number" prepend-inner-icon="mdi-clock" v-model="duration"
            :rules="[rules.required]" suffix="min" />

        <v-text-field label="Brief description of activity" prepend-inner-icon="mdi-human-male-board"
            v-model="brief_description" :rules="[rules.required]" />

        <v-textarea label="Description of activity" prepend-inner-icon="mdi-text-box-edit"
            v-model="description"></v-textarea>

        <v-radio-group v-model="date_radio" inline>
            <v-radio label="Choose activity date" value="choose"></v-radio>
            <v-radio label="Pending" value="pending"></v-radio>
        </v-radio-group>
        <v-text-field v-model="date" v-if="date_radio == 'choose'" type="date" label="Date" :rules="[rules.required]" />
        <v-btn color="green" text="Create" type="submit" block></v-btn>
    </v-form>
</template>

<script lang="ts" setup>
import { Ref, ref } from 'vue'
import axios from 'axios'

const name = ref("")
const max_volunteer = ref(undefined)
const duration = ref()
const date = ref()
const location = ref()
const description = ref("")
const brief_description = ref("")


const date_radio = ref("pending")
const rules = { required: (value: any) => !!value || 'This field is required' }

interface Activity {
    name: string,
    date?: Date,
    max_volunteer?: number,
    brief_description: string,
    location:string,
    description: string,
    duration: number,// minutes
}

async function submit() {
    console.log(date_radio.value)
    console.log(date.value)

    if (date_radio.value == "pending") {
        date.value = undefined
    }

    let data: Activity = {
        name: name.value,
        date: new Date(date.value),
        max_volunteer: Number(max_volunteer.value),
        location:location.value,
        duration: Number(duration.value),
        brief_description: brief_description.value,
        description: description.value
    };
    let result = await axios.post("/api/v1/activity", data)

}
</script>



