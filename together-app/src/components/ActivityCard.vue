<template>
    <v-card class="mx-auto" max-width="368" @click="$emit('click', modelValue)">
        <v-card-item :title="modelValue.name">
            <template v-slot:subtitle>
                <v-icon icon="mdi-map-marker" size="18" class="me-1 pb-1"></v-icon>
                {{ modelValue.location }}
            </template>
        </v-card-item>

        <v-card-text class="py-0">
            <v-row align="center" no-gutters>
                <v-col cols="6">
                    {{ modelValue.brief_description || modelValue.description}}
                </v-col>

                <v-col cols="6" class="text-right">
                    <v-icon color="error" icon="mdi-weather-hurricane" size="88"></v-icon>
                </v-col>
            </v-row>
        </v-card-text>



        <div class="d-flex py-3 justify-space-between">
            <v-list-item density="compact" prepend-icon="mdi-account-group">
                <v-list-item-subtitle>{{ modelValue.volunteer_num }}/{{ modelValue.max_volunteer_num || "?"
                }}</v-list-item-subtitle>
            </v-list-item>
        </div>

        <v-progress-linear
            :model-value="(modelValue.volunteer_num / (modelValue.max_volunteer_num || 20)) * 100"></v-progress-linear>


    </v-card>
</template>


<script lang="ts" setup>
import { Activity } from '@/types'


defineProps(['modelValue'])
defineEmits({
    click(activity: Activity) {

    }
})





</script>
