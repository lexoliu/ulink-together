// Composables
import { createRouter, createWebHistory } from 'vue-router'

const routes = [
  {
    path: '/',
    component: () => import('@/layouts/default/Default.vue'),
    children: [
      {
        path: '',
        name: 'Square',
        component: () => import(/* webpackChunkName: "home" */ '@/views/Square.vue'),
      },

      {
        path: 'record',
        name: 'Record',
        component: () => import(/* webpackChunkName: "record" */ '@/views/Record.vue'),
      },
      {
        path: 'message',
        name: 'Message',
        component: () => import(/* webpackChunkName: "message" */ '@/views/Message.vue'),
      },
      {
        path: 'account',
        name: 'Account',
        component: () => import(/* webpackChunkName: "account" */ '@/views/Account.vue'),
      },

      {
        path: 'activity/manage',
        name: 'Manage Activity List',
        component: () => import(/* webpackChunkName: "manage_activity_list" */ '@/views/ManageActivityList.vue'),
      },


      {
        path: 'activity/manage/:id',
        name: 'Manage Activity',
        component: () => import(/* webpackChunkName: "manage_activity" */ '@/views/ManageActivity.vue'),
      },

      {
        path: 'activity/create',
        name: 'Create Activity',
        component: () => import(/* webpackChunkName: "create_activity" */ '@/views/CreateActivity.vue'),
      },

      {
        path: 'activity/:id',
        name: 'View Activity',
        component: () => import(/* webpackChunkName: "view_activity" */ '@/views/ViewActivity.vue'),
      },


    ],
    
  },
  {
    path: '/login',
    name: 'Login',
    component: () => import(/* webpackChunkName: "login" */ '@/views/Login.vue'),
  },
  {
    path: '/register',
    name: 'Register',
    component: () => import(/* webpackChunkName: "register" */ '@/views/Register.vue'),
  },
  
]

const router = createRouter({
  history: createWebHistory(process.env.BASE_URL),
  routes,
})

export default router
