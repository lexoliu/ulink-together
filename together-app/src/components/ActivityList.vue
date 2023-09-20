<template>
    <div v-for="(activity,i) in modelValue" :key="i" class="py-3">
       <activity-card v-model="modelValue[i]" @click="$emit('click', modelValue[i])"/>
    </div>
</template>

<script lang="ts" setup>
import { useRouter } from 'vue-router'
import { Activity } from '@/types'
import ActivityCard from './ActivityCard.vue';


defineProps(['modelValue'])
defineEmits({
    click(activity: Activity) {

    }
})




const router = useRouter()


</script>
