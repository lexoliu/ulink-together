import { useMemo } from 'react'
import {
  Area,
  AreaChart,
  Bar,
  BarChart,
  CartesianGrid,
  Cell,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts'

import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { formatDateOnly } from '@/lib/format'
import type { ActivitySummary } from '@/lib/types'

interface HomeActivityChartProps {
  activities: ActivitySummary[]
}

const statePalette: Record<string, string> = {
  Recruiting: '#4b5563',
  'In Progress': '#6b7280',
  Completed: '#94836d',
  Cancelled: '#bcaea6',
}

export function HomeActivityChart({ activities }: HomeActivityChartProps) {
  const stateData = useMemo(() => {
    const counts = new Map<string, number>([
      ['Recruiting', 0],
      ['In Progress', 0],
      ['Completed', 0],
      ['Cancelled', 0],
    ])

    for (const activity of activities) {
      switch (activity.state) {
        case 'need_volunteer':
          counts.set('Recruiting', (counts.get('Recruiting') ?? 0) + 1)
          break
        case 'going':
          counts.set('In Progress', (counts.get('In Progress') ?? 0) + 1)
          break
        case 'ended':
          counts.set('Completed', (counts.get('Completed') ?? 0) + 1)
          break
        case 'canceled':
          counts.set('Cancelled', (counts.get('Cancelled') ?? 0) + 1)
          break
      }
    }

    return Array.from(counts.entries()).map(([label, value]) => ({
      label,
      value,
      fill: statePalette[label],
    }))
  }, [activities])

  const upcomingData = useMemo(() => {
    return activities
      .filter((activity) => activity.date)
      .slice()
      .sort((left, right) => (left.date ?? '').localeCompare(right.date ?? ''))
      .slice(0, 6)
      .map((activity) => ({
        label: activity.name.length > 18 ? `${activity.name.slice(0, 18)}…` : activity.name,
        joined: activity.volunteer_num,
        capacity: activity.max_volunteer_num ?? activity.volunteer_num,
        date: formatDateOnly(activity.date),
      }))
  }, [activities])

  return (
    <Card className="border-white/70 bg-white/88 shadow-lg shadow-slate-200/40">
      <CardHeader>
        <CardTitle>Overview</CardTitle>
      </CardHeader>
      <CardContent className="grid min-w-0 gap-6 xl:grid-cols-2">
        <div className="min-w-0 rounded-[1.7rem] border border-slate-200/80 bg-slate-50/70 p-4">
          <p className="text-[11px] font-semibold uppercase tracking-[0.22em] text-slate-400">
            Activity states
          </p>
          <div className="mt-4 h-64 min-w-0">
            <ResponsiveContainer width="100%" height="100%" minWidth={0}>
              <BarChart data={stateData} barCategoryGap={18}>
                <CartesianGrid vertical={false} stroke="#e7e5e4" />
                <XAxis dataKey="label" tickLine={false} axisLine={false} tick={{ fill: '#78716c', fontSize: 12 }} />
                <YAxis allowDecimals={false} tickLine={false} axisLine={false} tick={{ fill: '#78716c', fontSize: 12 }} />
                <Tooltip
                  cursor={{ fill: 'rgba(28, 25, 23, 0.04)' }}
                  contentStyle={{
                    borderRadius: '18px',
                    border: '1px solid rgba(214, 211, 209, 0.9)',
                    boxShadow: '0 18px 44px -24px rgba(28,25,23,0.22)',
                  }}
                />
                <Bar dataKey="value" radius={[12, 12, 0, 0]}>
                  {stateData.map((entry) => (
                    <Cell key={entry.label} fill={entry.fill} />
                  ))}
                </Bar>
              </BarChart>
            </ResponsiveContainer>
          </div>
        </div>

        <div className="min-w-0 rounded-[1.7rem] border border-slate-200/80 bg-slate-50/70 p-4">
          <p className="text-[11px] font-semibold uppercase tracking-[0.22em] text-slate-400">
            Upcoming capacity
          </p>
          <div className="mt-4 h-64 min-w-0">
            {upcomingData.length > 0 ? (
              <ResponsiveContainer width="100%" height="100%" minWidth={0}>
                <AreaChart data={upcomingData}>
                  <defs>
                    <linearGradient id="joinedFill" x1="0" x2="0" y1="0" y2="1">
                      <stop offset="5%" stopColor="#4b5563" stopOpacity={0.22} />
                      <stop offset="95%" stopColor="#4b5563" stopOpacity={0} />
                    </linearGradient>
                  </defs>
                  <CartesianGrid vertical={false} stroke="#e7e5e4" />
                  <XAxis dataKey="label" tickLine={false} axisLine={false} tick={{ fill: '#78716c', fontSize: 12 }} />
                  <YAxis allowDecimals={false} tickLine={false} axisLine={false} tick={{ fill: '#78716c', fontSize: 12 }} />
                  <Tooltip
                    contentStyle={{
                      borderRadius: '18px',
                      border: '1px solid rgba(214, 211, 209, 0.9)',
                      boxShadow: '0 18px 44px -24px rgba(28,25,23,0.22)',
                    }}
                    formatter={(value, name) => [
                      value,
                      name === 'joined' ? 'Joined volunteers' : 'Capacity',
                    ]}
                    labelFormatter={(_, payload) => payload?.[0]?.payload?.date ?? ''}
                  />
                  <Area
                    type="monotone"
                    dataKey="joined"
                    stroke="#4b5563"
                    strokeWidth={2.5}
                    fill="url(#joinedFill)"
                  />
                  <Area
                    type="monotone"
                    dataKey="capacity"
                    stroke="#a8a29e"
                    strokeDasharray="5 5"
                    strokeWidth={2}
                    fillOpacity={0}
                  />
                </AreaChart>
              </ResponsiveContainer>
            ) : (
              <div className="flex h-full items-center justify-center text-sm text-slate-500">
                Scheduled activities will appear here once dates are set.
              </div>
            )}
          </div>
        </div>
      </CardContent>
    </Card>
  )
}
