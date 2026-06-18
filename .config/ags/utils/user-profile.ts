import { createState } from "ags";
import type { User } from "../class/Supabase.class";

export const [userProfile, _setUserProfile] = createState<User | null>(null);

export const updateUserProfile = (profile: User | null) => {
  // console.table(profile);
  _setUserProfile(profile);
};

export const clearUserProfile = () => {
  updateUserProfile(null);
};
