import type { Metadata } from 'next';
import './globals.css';
import ArrivalScreen from '@/components/sidewalk/arrival-screen';
export const metadata:Metadata={title:'Sidewalk — San Francisco, on foot',description:'Plan San Francisco walking routes with architecture, history, and film stops.',icons:{icon:'/favicon.svg',shortcut:'/favicon.svg'}};
export default function RootLayout({children}:{children:React.ReactNode}){return <html lang="en"><body><ArrivalScreen>{children}</ArrivalScreen></body></html>}
