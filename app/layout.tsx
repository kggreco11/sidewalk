import type { Metadata } from 'next';
import './globals.css';
export const metadata:Metadata={title:'Sidewalk — San Francisco, on foot',description:'Turn your next walk into a small discovery. Explore San Francisco architecture, history, and film locations along the way.',icons:{icon:'/favicon.svg',shortcut:'/favicon.svg'}};
export default function RootLayout({children}:{children:React.ReactNode}){return <html lang="en"><body>{children}</body></html>}
