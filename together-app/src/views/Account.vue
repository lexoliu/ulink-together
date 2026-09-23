<template>
    <v-list>
      <v-list-item
        v-for="item in items"
        @click="router.push({name:item.route_name})"
      >
        <template v-slot:prepend>
          <v-icon :icon="item.icon"></v-icon>
        </template>

        <v-list-item-title v-text="item.route_name"></v-list-item-title>
      </v-list-item>
    </v-list>
</template>

<script lang="ts" setup>
import { useRouter } from 'vue-router';

const router=useRouter();
interface Item{
    icon:string,
    route_name:string,
}
const items:Item[]=[{icon:"mdi-security",route_name:"Manage Activity List"}]

</script>
