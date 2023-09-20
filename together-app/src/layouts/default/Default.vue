<template>
  <v-layout >
    <v-app-bar color="green" density="prominent">
      <template v-slot:prepend>
        <v-app-bar-nav-icon></v-app-bar-nav-icon>
      </template>

      <v-app-bar-title>{{ route.name }}</v-app-bar-title>
      <template v-slot:append>
        <v-btn icon>
          <v-icon>mdi-dots-vertical</v-icon>
        </v-btn>
      </template>
    </v-app-bar>

    <v-main class="h-screen overflow-y-auto">
      <v-container>
        
        <router-view />
      </v-container>
    </v-main>

    <v-bottom-navigation grow>
      <v-btn value="square" @click="router.push('/')">
        <v-icon>mdi-seesaw</v-icon>

        <span>Square</span>
      </v-btn>


      <v-btn value="record" @click="router.push('/record')">
        <v-icon>mdi-content-save</v-icon>

        <span>Record</span>
      </v-btn>
      <v-btn value="message" @click="router.push('/message')">
        <v-icon>mdi-message</v-icon>

        <span>Message</span>
      </v-btn>

      <v-btn value="account" @click="router.push('/account')">
        <v-icon>mdi-account</v-icon>

        <span>Me</span>
      </v-btn>
    </v-bottom-navigation>
  </v-layout>
</template>

<script lang="ts" setup>
import { useRoute, useRouter } from 'vue-router';
const route = useRoute()
const router = useRouter()


</script>
