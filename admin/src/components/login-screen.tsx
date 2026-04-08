import { ShieldCheck } from 'lucide-react'

import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'

interface LoginScreenProps {
  email: string
  password: string
  pending: boolean
  errorMessage?: string | null
  onEmailChange: (value: string) => void
  onPasswordChange: (value: string) => void
  onSubmit: () => Promise<void>
}

export function LoginScreen({
  email,
  password,
  pending,
  errorMessage,
  onEmailChange,
  onPasswordChange,
  onSubmit,
}: LoginScreenProps) {
  return (
    <div className="min-h-screen bg-[radial-gradient(circle_at_top_right,_rgba(148,163,184,0.1),_transparent_30%),linear-gradient(to_bottom,_#f7f5f2,_#f1efe9)] px-6 py-12">
      <div className="mx-auto grid max-w-4xl gap-8 lg:grid-cols-[1fr_0.95fr]">
        <section className="flex flex-col justify-between rounded-[2rem] border border-white/70 bg-white/75 p-8 shadow-2xl shadow-slate-200/70 backdrop-blur">
          <div>
            <p className="text-sm font-medium uppercase tracking-[0.18em] text-slate-500">
              Admin
            </p>
            <h1 className="mt-4 max-w-xl text-5xl font-semibold tracking-tight text-slate-950">
              Volunteer operations
            </h1>
          </div>
        </section>

        <Card className="border-white/70 bg-white/85 shadow-2xl shadow-slate-200/60 backdrop-blur">
          <CardHeader className="space-y-3">
            <div className="flex size-11 items-center justify-center rounded-2xl bg-slate-950 text-white">
              <ShieldCheck className="size-5" />
            </div>
            <div>
              <CardTitle>Sign in</CardTitle>
            </div>
          </CardHeader>
          <CardContent>
            <form
              className="grid gap-5"
              onSubmit={async (event) => {
                event.preventDefault()
                await onSubmit()
              }}
            >
              <div className="grid gap-2">
                <Label htmlFor="email">Email</Label>
                <Input
                  id="email"
                  autoComplete="username"
                  value={email}
                  onChange={(event) => onEmailChange(event.target.value)}
                />
              </div>
              <div className="grid gap-2">
                <Label htmlFor="password">Password</Label>
                <Input
                  id="password"
                  type="password"
                  autoComplete="current-password"
                  value={password}
                  onChange={(event) => onPasswordChange(event.target.value)}
                />
              </div>

              {errorMessage ? (
                <p className="rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
                  {errorMessage}
                </p>
              ) : null}

              <Button type="submit" size="lg" disabled={pending}>
                {pending ? 'Signing in…' : 'Enter dashboard'}
              </Button>
            </form>
          </CardContent>
        </Card>
      </div>
    </div>
  )
}
