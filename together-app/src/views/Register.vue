<template>
  <v-form ref="form" class="d-flex h-screen justify-center align-center" @submit.prevent="register">
    <v-card class="pa-6" min-width="350">

      <div class="text-h4 mb-6">Register</div>

      <v-text-field type="email" v-model="email" placeholder="Email address" label="Email"
        prepend-inner-icon="mdi-email-outline" :rules="[rules.required]" />

      <v-text-field v-model="realname" placeholder="Your realname" label="Real name" prepend-inner-icon="mdi-account"
        :rules="[rules.required]" />

      <v-text-field v-model="password" type="password" label="Password" placeholder="Enter your password"
        :rules="[rules.required]" prepend-inner-icon="mdi-lock-outline" />
      <v-radio-group v-model="gender_radio" :rules="[rules.required]" inline>
        <v-radio label="Male" value="Male" />
        <v-radio label="Female" value="Female" />
        <v-radio label="Other" value="Other" />

      </v-radio-group>

      <div>
        <v-select v-model="grade"  label="Grade" :items="['G1', 'G2', 'Pre', 'AS', 'A2']" :rules="[rules.required]"/>
        <v-text-field type="number" label="Class ID" v-model="class_id" prepend-inner-icon="mdi-tag" :rules="[rules.required]" />
      </div>
      <v-text-field v-model="other_gender" :rules="[rules.required]" placeholder="Your gender (please be serious)"
        label="Gender" prepend-inner-icon="mdi-gender-male-female" v-if="gender_radio == 'Other'" />

      <v-card class="mb-12" variant="tonal">
        <v-card-text>
          Warning: Make sure all of the information is proper
        </v-card-text>
      </v-card>

      <v-btn block type="submit" class="mb-8" color="blue" size="large">
        Register
      </v-btn>

      <v-card-text class="text-center">
        <a class="text-blue text-decoration-none" @click="router.push({ name: 'Login' })">
          Sign up now <v-icon icon="mdi-chevron-right"></v-icon>
        </a>
      </v-card-text>
    </v-card>
  </v-form>
</template>

<script lang="ts" setup>
import { useRouter } from 'vue-router'

import axios from 'axios'
import hash from 'hash.js'
import { ref } from 'vue'
const router = useRouter()
const form = ref()
const email = ref("")
const realname = ref("")
const gender_radio = ref("")
const other_gender = ref("")
const password = ref("")
const grade = ref("");
const class_id = ref("")

async function register(this: any) {
  if (gender_radio.value != "Other") {
    other_gender.value = gender_radio.value
  }

  const { valid } = await form.value.validate()
  if (!valid) {
    return
  }

  let result=await axios.post("/api/v1/user", {
    email: email.value,
    realname: realname.value,
    classname:grade.value+"-"+class_id.value,
    gender: other_gender.value,
    password: hash.sha256().update(password.value).digest('hex')
  })

  router.push({name:"Login"})

}
const rules = { required: (value: any) => !!value || 'This field is required' }

</script>
