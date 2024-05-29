let
  iris = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDszXhyyhG7wI9R5+CiEQziDo3Ryosg6K2kPEtaCpQOZ mtaku3@iris";
in {
  "secrets/users/mtaku3@iris/password.age".publicKeys = [iris];
}
