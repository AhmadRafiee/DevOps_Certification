source: https://developer.hashicorp.com/vagrant/docs
# Installing
در Vagrant میتوانیم یک ماشین مجازی با استفاده از کانفیگی که در Vagrantfile قرار دادیم ایجاد کنیم. اگر به یک محیط صفر یا بکر نیازمند باشیم کانفیگ های آماده در Vagrant وجود دارند و قابل استفاده هستند
## Add the HashiCorp GPG key.
```shell
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
```

## Add the official HashiCorp Linux repository.
```shell
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
```

## Update and install.
```shell
sudo apt-get update
sudo apt-get install vagrant
sudo apt-get install packer
```

# Add public box in vagrant
در وگرنت box درواقع همان image است

چرا در vagrant از کلمه **image** استفاده نمی‌شود؟
در برخی سیستم‌های مجازی‌سازی دیگر (مثل Docker)، واژه **image** به کار می‌رود، اما Vagrant قصد دارد تا از مفاهیم مرسوم مجازی‌سازی سنتی کمی فاصله بگیرد و تمرکز بیشتری بر انعطاف‌پذیری و ساده‌سازی محیط‌های توسعه داشته باشد.

بنابراین، استفاده از واژه **box** بیشتر برای این است که با فلسفه و رویکرد خاص Vagrant سازگاری داشته باشد و این تمایز را ایجاد کند که با یک محیط سبک و قابل توسعه سروکار داریم، نه یک سیستم کامل و از پیش آماده مثل یک **image** سنتی.

شرکت های مختلفی برای تعامل با وگرنت باکس های خودشان را ایجاد میکنند و در اختیار عموم قرار میدهند مانند bento
## Adding a bento box to Vagrant

```shell
vagrant box add --provider virtualbox bento/ubuntu-22.04
vagrant box add --provider virtualbox bento/debian-12
```
# provider
- وگرنت برای provider های مختلفی میتواند box داشته باشد. این پرووایدر ها نقش استفاده و اجرای ماشین با استفاده از باکس را دارند. مانند VMWare یا Oracle Virtualbox
- قطعا باکسهای پرووایدر های مختلف، با هم دیگر تفاوت دارند. بنابراین در هنگام add کردن باید پرووایدر آن را هم تعریف کنیم.
# Running a box with Vagrantfile
در پوشه ای که Vagrantfile ما قرار دارد قرار میگیرد.
1. ابتدا با دستور validate سلامت فایل را بررسی میکنیم.
2. سپس با دستور up فایل را اجرا میکنیم.
```bash
vagrant validate
vagrant up
```
# Vagrantfile
فایل Vagrant (معروف به `Vagrantfile`) به طور پیش‌فرض با زبان Ruby نوشته می‌شود و Vagrant به طور مستقیم از Ruby برای پیکربندی استفاده می‌کند
## Base part of Vagrantfile
```ruby
Vagrant.configure("2") do |config|
  config.vm.box = "bento/ubuntu-20.04"
end
```

```ruby
Vagrant.configure("2") do |config|
  config.vm.box = "bento/debian-12"
end
```
- مثالهای بالا آغاز پیکربندی Vagrant است. `"2"` نشان می‌دهد که از نسخه ۲ پیکربندی Vagrant استفاده می‌شود.
- این خطوط به صورت **بلاک‌های کد** نوشته شده‌اند تا مجموعه‌ای از تنظیمات را برای پیکربندی Vagrant اعمال کنند. این روش نوشتن مبتنی بر **ساختارهای زبان Ruby** است، که Vagrantfile نیز بر اساس آن نوشته شده است.
- کلمه `do` در زبان **Ruby** برای شروع یک **بلاک** استفاده می‌شود. یک بلاک در Ruby شبیه به یک قطعه کد یا مجموعه‌ای از دستورات است که درون آن می‌توانیم تنظیمات یا رفتار خاصی را تعریف کنیم.
- وقتی از `do` استفاده می‌کنیم، یک بلاک کد را باز می شود که معمولاً در انتها با `end` خاتمه می‌یابد.
- قسمت **`|config|`**:  نشان می‌دهد که ما یک آرگومان به نام `config` را به این بلاک منتقل می‌کنیم. از این آرگومان به عنوان یک آبجکت برای تنظیمات Vagrant در این بلاک استفاده می شود.
- این آبجکت (در اینجا `config`) میتواند متدهای مختلفی رو به صورت زنجیره‌ای فراخوانی کند، مواردی مثل vm.box
- آبجکت ها میتوانند دوباره با یک آرگومان جدید تنظیمات زیرشاخه ای داشته باشند. مثل : 

`config.vm.provider "virtualbox" do |my_vm|`

## Machine Settings
- تمامی تنظیمات ماشین در Vagrantfile با آبجکت و متد `config.vm` آغاز میشود که لیست تنظیمات در دسترس را میتوان در این آدرس مشاهده کرد: [Vagrantfile Available Settings](https://developer.hashicorp.com/vagrant/docs/vagrantfile/machine_settings)
## Defining Multiple Machines
- اگر لیست تنظیمات ماشین رو در آدرس بالا مشاهده کنیم آیتم `config.vm.define` که جلوتر در Expert sample file مشاهده میکنیم، وجود ندارد. 
- علت آن است که این آیتم جزو تنظیمات ماشین نیست بلکه زمانی که میخواهیم مجموعه ای از ماشینها را (چه با استفاده از حلقه و چه خارج از حلقه) تعریف کنیم از define استفاده میکنیم.
## Vagrantfile Samples
### simple sample file
```ruby
IMAGE_ubuntu_2204   = "bento/ubuntu-22.04"
IMAGE_Debian_12     = "bento/debian-12"

Vagrant.configure("2") do |config|
  config.vm.box = IMAGE_ubuntu_2204
  config.vm.hostname = "test"
  config.vm.provider "virtualbox" do |my_vm|
    my_vm.name = "my_vm"
    my_vm.memory = 1024
    my_vm.cpus = 1
  end
  config.vm.provision :shell, path: "bootstrap.sh"
end

```

### Expert sample file
```ruby
IMAGE_ubuntu_2204   = "bento/ubuntu-22.04"
IMAGE_Debian_12     = "bento/debian-12"

ENV['VAGRANT_NO_PARALLEL'] = 'yes'

Vagrant.configure(2) do |config|
  config.vm.provision "shell", path: "bootstrap.sh"

  NodeType1 = 2
  (1..NodeType1).each do |type1_id|
    config.vm.define "type1#{type1_id}" do |type1_vm|
      type1_vm.vm.box = IMAGE_Debian_12
      type1_vm.vm.hostname = "type1#{type1_id}"
      type1_vm.vm.network "private_network", ip: "192.168.56.10#{type1_id}"
      type1_vm.vm.provider "virtualbox" do |v|
        v.name = "type1#{type1_id}"
        v.memory = 1024
        v.cpus = 1
      end
      type1_vm.vm.provision "shell", path: "bootstrap_t1.sh"
    end
  end


  NodeType2 = 0
  (1..NodeType2).each do |type2_id|
    config.vm.define "type2#{type2_id}" do |type2_vm|
      type2_vm.vm.box = IMAGE_Debian_12
      type2_vm.vm.hostname = "type2#{type2_id}.example.com"
      type2_vm.vm.network "private_network", ip: "192.168.56.11#{type2_id}"
      type2_vm.vm.provider "virtualbox" do |v|
        v.name = "type2#{type2_id}"
        v.memory = 1024
        v.cpus = 1
      end
      type2_vm.vm.provision "shell", path: "bootstrap_t2.sh"
    end
  end
end

```
- در مثال بالا (expert) دو نوع ماشین مجازی ایجاد می‌کنیم، از نوع اول دو عدد و از نوع دوم صفر عدد (یعنی در صورت لزوم با تغییر مقدار متغیرها میتوانیم از نوع دوم هم ماشین هایی ایجاد کنیم)
تشریح قسمت های مختلف فایل:

- **`ENV['VAGRANT_NO_PARALLEL'] = yes`**

	مانع اجرای هم‌زمان چند ماشین می‌شود.

- **`config.vm.provision "shell", path: "bootstrap.sh"`**

	در واقع به عنوان یک تنظیم اولیه برای ماشین‌های مجازی در Vagrant است، اما اجرای آن بعد از ایجاد ماشین‌ها انجام می‌شود.وقتی که `vagrant up` اجرا می‌شود، ابتدا ماشین‌ها ساخته می‌شوند. سپس، پس از بوت شدن ماشینهای مجازی، Vagrant شروع به اجرای بخش‌های `provision` می‌کند. قرار دادن این خط در ابتدای `Vagrantfile` قبل از تعریف دو `NodeType`، به این دلیل است که این دستور برای تمامی ماشینها اعمال شود.

- **`NodeType1 = 2`**

	این متغیر تعداد ماشین‌های نوع 1 را مشخص می‌کند که برابر با 2 است.

- **`(1..NodeType1).each do |type1_id|`**

	این حلقه از 1 تا 2 اجرا می‌شود و برای هر عدد یک ماشین مجازی ایجاد می‌کند.

- **`config.vm.define "type1#{type1_id}"`**

	با استفاده از متغیر `type1_id`، نام هر ماشین مجازی به صورت `type1` به همراه شماره‌اش (مثلاً type1_1 و type1_2) تعریف می‌شود.

- **`type1_vm.vm.box = IMAGE_Debian_12`**

	سیستم‌عامل ماشین‌های مجازی از یک box با نام `bento/debian-12` استفاده می‌کند که قبلاً تعریف شده است.

- **`type1_vm.vm.hostname = "type1#{type1_id}"`**

	متد hostname برای هر ماشین به نام `type1` و شماره‌اش تنظیم می‌شود، مثلاً `type1_1` و `type1_2`.

- **`type1_vm.vm.network "private_network", ip: "192.168.56.10#{type1_id}"`**

	هر ماشین مجازی به یک شبکه خصوصی متصل شده و IP آن‌ها به ترتیب `192.168.56.101` و `192.168.56.102` است.

- **`type1_vm.vm.provider "virtualbox" do |v|`**

	این بلاک مشخص می‌کند که ماشین‌ها باید روی VirtualBox اجرا شوند.

- **`v.name = "type1#{type1_id}"`**

	نام ماشین در VirtualBox به ترتیب `type1_1` و `type1_2` است.

- **`v.memory = 1024 و v.cpus = 1`**

	هر ماشین مجازی 1 گیگابایت RAM و 1 پردازنده اختصاص داده شده است.

- **`type1_vm.vm.provision "shell", path: "bootstrap_t1.sh"`**

	در نهایت، پس از ایجاد ماشین، یک اسکریپت به نام `bootstrap_t1.sh` برای پیکربندی بیشتر ماشین اجرا می‌شود.

---

سوال: این دو خط در فایل باهم چه تفاوتی دارند؟
**(type1_vm.vm.hostname = "type1#{type1_id}")**: 
**(v.name = "type1#{type1_id}")**:

 پاسخ:
	- **(type1_vm.vm.hostname = "type1#{type1_id}")**: 
	این خط، hostname (نام میزبان) ماشین مجازی را تنظیم می‌کند. این نام داخل سیستم‌عامل ماشین مجازی استفاده می‌شود و معمولاً در ارتباطات شبکه‌ای داخل ماشین و بین ماشین‌ها کاربرد دارد. به عنوان مثال، در داخل ماشین وقتی دستور `hostname` را اجرا کنیم، نتیجه این تنظیم را خواهید دید.
	- **(v.name = "type1#{type1_id}")**:
	این خط نام ماشین مجازی را در VirtualBox تنظیم می‌کند. این نام در محیط مدیریت VirtualBox نمایش داده می‌شود و برای شناسایی ماشین‌ها در پنل VirtualBox یا ابزارهای مدیریتی دیگر استفاده می‌شود. 

---
# Vagrant Environment
- متغیرهای محیطی (environment variables) در Vagrant نقش مهمی در پیکربندی و کنترل رفتار آن دارند. متغیرهای محیطی مختلفی برای تنظیمات Vagrant وجود دارند که هر یک عملکرد خاصی را ارائه می‌دهند. از جمله متغیرهایی مانند `VAGRANT_NO_PARALLEL` که مانع اجرای موازی ماشین‌های مجازی می‌شود.

- تعداد متغیرها ممکن است با نسخه‌های مختلف Vagrant تغییر کند. اما برخی از متغیرهای معروف و پرکاربرد شامل موارد زیر هستند:
1. **VAGRANT_HOME**:
	
	محل دایرکتوری اصلی Vagrant را تعیین می‌کند.
	
2. **VAGRANT_CWD**:

	دایرکتوری فعلی کاری برای Vagrant را تنظیم می‌کند.
	
3. **VAGRANT_LOG**:

	سطح لاگ (log level) برای خطاها و گزارش‌های Vagrant را مشخص می‌کند.
	
4. **VAGRANT_NO_PARALLEL**:

	جلوگیری از اجرای موازی ماشین‌های مجازی در زمان اجرای `vagrant up`.
	
5. **VAGRANT_DEFAULT_PROVIDER**:

	تعیین می‌کند که کدام provider (مثلاً `virtualbox`، `libvirt`، و غیره) به صورت پیش‌فرض استفاده شود.
	
6. **VAGRANT_VAGRANTFILE**:

	محل فایل `Vagrantfile` را مشخص می‌کند.
	
	
---

- لیست کامل این متغیرها و توضیحات مربوط به آنها را می‌توانید در مستندات رسمی Vagrant در بخش [Environment Variables](https://developer.hashicorp.com/vagrant/docs/other/environmental-variables) مشاهده کنیم.

- تعداد این متغیرها زیاد است و معمولاً با نیاز خاص پروژه‌ها استفاده می‌شوند، اما اکثر پروژه‌ها فقط از چند مورد رایج مانند موارد بالا استفاده می‌کنند.