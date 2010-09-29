module Net; module SSH

  class KnownHosts

    def self.add_or_replace(host, key)
      host.split(",").each do |h|
        system "ssh-keygen -R #{h}" # TODO: do this natively, without ssh-keygen
      end
      add(host, key)
    end

  end
end; end