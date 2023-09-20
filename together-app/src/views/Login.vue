<template>
  <v-form ref="form" class="d-flex h-screen justify-center align-center" @submit.prevent="login">
    <v-card class="pa-6" min-width="350">

      <div class="text-h4 mb-6">Login</div>

      <v-text-field type="email" v-model="email" placeholder="Email address" label="Email"
        prepend-inner-icon="mdi-email-outline" :rules="[rules.required]" />


      <v-text-field v-model="password" type="password" label="Password" placeholder="Enter your password"
        :rules="[rules.required]" prepend-inner-icon="mdi-lock-outline" />

      <a class="text-caption text-decoration-none text-blue" @click="forget_password">
        Forgot login password?</a>


      <v-btn block type="submit" class="mb-8" color="blue" size="large">
        Login
      </v-btn>

      <v-card-text class="text-center">
        <a class="text-blue text-decoration-none" @click="router.push({ name: 'Register' })">
          Register now <v-icon icon="mdi-chevron-right"></v-icon>
        </a>
      </v-card-text>
    </v-card>
  </v-form>
</template>

<script lang="ts" setup>
import { ref } from 'vue'
import { useRouter } from 'vue-router'

import axios from 'axios'
import hash from 'hash.js'

const router = useRouter()

const email = ref("")
const password = ref("")

function forget_password() {
  alert('Go to IT department please')
}

const form = ref()

const rules = { required: (value: any) => !!value || 'This field is required' }

async function login() {

  const { valid } = await form.value.validate()
  if (!valid) {
    return
  }

  axios.post("/api/v1/login", {
    email: email.value,
    password: hash.sha256().update(password.value).digest('hex')

  }).then(() => router.push({ name: "Square" }))
}

</script>



