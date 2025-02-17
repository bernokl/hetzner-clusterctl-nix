{
  description = "virtual environments";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs";
  inputs.devshell.url = "github:numtide/devshell";
  inputs.flake-parts.url = "github:hercules-ci/flake-parts";

  outputs = inputs@{ self, flake-parts, devshell, nixpkgs }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        devshell.flakeModule
      ];

      systems = [ "x86_64-linux" ];

      perSystem = { pkgs, ... }: {
        devshells.default = {
          packages = with pkgs; [
            k9s
            kubectl
            clusterctl
            kind
            helmfile
          ];
          commands = [
            {
              package = pkgs.writeShellScriptBin "setup-kind" ''
                kind create cluster --name hetzner
                kind get kubeconfig --name hetzner > kubeconfig
              '';
              name = "1-setup-kind";
              category = "setup";
            }
            {
              package = pkgs.writeShellScriptBin "setup-management-cluster" ''
                clusterctl init --core cluster-api --bootstrap kubeadm --control-plane kubeadm --infrastructure hetzner
              '';
              name = "2-setup-management-cluster";
              category = "setup";
            }
            {
              package = pkgs.writeShellScriptBin "create-secret" ''
                kubectl create secret generic hetzner --from-literal=hcloud=$HCLOUD_TOKEN
                kubectl patch secret hetzner -p '{"metadata":{"labels":{"clusterctl.cluster.x-k8s.io/move":""}}}'
              '';
              name = "3-create-secret";
              category = "setup";
            }
            {
              package = pkgs.writeShellScriptBin "generate-cluster-yaml" ''
                clusterctl generate cluster my-cluster --kubernetes-version v1.29.4 --control-plane-machine-count=1 --worker-machine-count=1  > my-cluster.yaml
              '';
              name = "4-generate-cluster-yaml";
              category = "setup";
            }
            {
              package = pkgs.writeShellScriptBin "provision-cluster" ''
                kubectl apply -f my-cluster.yaml
                kubectl get cluster
                clusterctl describe cluster my-cluster
                kubectl get kubeadmcontrolplane
                clusterctl get kubeconfig my-cluster > kubeconfig.hetzner.yaml
              '';
              name = "5-provision-cluster";
              category = "setup";
            }
            {
              package = pkgs.writeShellScriptBin "move-provisioning-to-cluster-itself" ''
                clusterctl init --core cluster-api --bootstrap kubeadm --control-plane kubeadm --infrastructure hetzner
                export KUBECONFIG=$LOCAL_KUBECONFIG
                clusterctl move --to-kubeconfig $HETZNER_KUBECONFIG
              '';
              name = "6-move-provisioning-to-cluster-itself";
              category = "setup";
            }
            {
              package = pkgs.writeShellScriptBin "delete-provisioned-cluster" ''
                KUBECONFIG=LOCAL_KUBECONFIG kubectl delete cluster my-cluster
              '';
              name = "7-delete-provisioned-cluster";
              category = "setup";
            }
          ];
        };
      };
    };
}
