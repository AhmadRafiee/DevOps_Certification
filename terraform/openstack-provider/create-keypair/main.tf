resource "openstack_compute_keypair_v2" "test-keypair" {
  name       = "my-keypair"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDjf9rnLY0YMPVu4Rp6g2rj36TTceoZdPvHl5SrI1YdtWi0iSGvs167Gt+tuqf03RSOS3B+sd7W+3LgJc3tgrPykF+nc+yro++CXRmwI+OO/eF6UNNslXQXxOhj4ZCdbz8q4pxLk48aUkLQdjcIPsKDFjEub8OEWcdpqSmOSF8JJerPtWE7pfW4pl8v+MMyDXtD9jkSnOTKO4kYvTKMGOptB4xHqkrC3KO6icKJIZQw38I4KWZhBnskVMPG7PSzBS1pa/pmy0ayNy9Z0iYSwzG/ESbDlH/PdGeMyEoIJFBSvjBxGTRF+HLA3xEdECoxr28xg6f921brocGysRLAUGfX ahmad@ahmad"
}

