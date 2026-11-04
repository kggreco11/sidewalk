import type {Place} from './types';
export type ExplorePlace=Place&{neighborhood?:string;teaser?:string;image?:string;imageCredit?:string;imageSource?:string;imageLicenseUrl?:string|null;imageLicense?:string;imageDate?:string};
